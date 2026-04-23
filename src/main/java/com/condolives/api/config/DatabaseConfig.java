package com.condolives.api.config;

import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.SQLFeatureNotSupportedException;
import java.sql.Statement;
import java.util.Map;
import java.util.Properties;
import java.util.logging.Logger;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

/**
 * Configuração central do banco de dados.
 *
 * Responsabilidades:
 *  1. DataSource com HikariCP (pool de conexões)
 *  2. RlsAwareDataSource — wrapper que injeta SET LOCAL app.current_condominium_id
 *     em cada conexão extraída do pool, garantindo isolamento por tenant no PostgreSQL
 *  3. EntityManagerFactory com Hibernate
 *  4. TransactionManager
 */
@Configuration
@EnableTransactionManagement
@EnableJpaAuditing
@EnableJpaRepositories(basePackages = "com.condolives.api.repository")
public class DatabaseConfig {

    @Value("${spring.datasource.url}")
    private String jdbcUrl;

    @Value("${spring.datasource.username}")
    private String username;

    @Value("${spring.datasource.password}")
    private String password;

    // ─────────────────────────────────────────────────────────
    // 1. DataSource com RLS interceptor
    // ─────────────────────────────────────────────────────────

    @Bean
    @Primary
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(jdbcUrl);
        config.setUsername(username);
        config.setPassword(password);
        config.setDriverClassName("org.postgresql.Driver");

        // Pool sizing — ajuste conforme carga esperada
        config.setMaximumPoolSize(20);
        config.setMinimumIdle(5);
        config.setIdleTimeout(600_000L);      // 10 min
        config.setConnectionTimeout(30_000L); // 30 s

        // Valida a conexão ao emprestar do pool
        config.setConnectionTestQuery("SELECT 1");

        return new RlsAwareDataSource(new HikariDataSource(config));
    }

    // ─────────────────────────────────────────────────────────
    // 2. EntityManagerFactory
    // ─────────────────────────────────────────────────────────

    @Bean
    @Primary
    public LocalContainerEntityManagerFactoryBean entityManagerFactory(DataSource dataSource) {
        Properties jpaProperties = new Properties();

        // DDL — usar "validate" em produção; "update" só em dev
        jpaProperties.put("hibernate.hbm2ddl.auto",              "validate");
        jpaProperties.put("hibernate.show_sql",                   "false");
        jpaProperties.put("hibernate.format_sql",                 "true");
        jpaProperties.put("hibernate.default_schema",             "public");
        jpaProperties.put("hibernate.dialect",                    "org.hibernate.dialect.PostgreSQLDialect");

        // Batch para melhor performance em inserts/updates em massa
        jpaProperties.put("hibernate.jdbc.batch_size",            "50");
        jpaProperties.put("hibernate.order_inserts",              "true");
        jpaProperties.put("hibernate.order_updates",              "true");
        jpaProperties.put("hibernate.jdbc.batch_versioned_data",  "true");

        LocalContainerEntityManagerFactoryBean factory = new LocalContainerEntityManagerFactoryBean();
        factory.setDataSource(dataSource);
        factory.setPackagesToScan("com.condolives.api.entity");
        factory.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
        factory.setJpaProperties(jpaProperties);

        return factory;
    }

    // ─────────────────────────────────────────────────────────
    // 3. TransactionManager
    // ─────────────────────────────────────────────────────────

    @Bean
    @Primary
    public PlatformTransactionManager transactionManager(DataSource dataSource) {
        return new JpaTransactionManager(entityManagerFactory(dataSource).getObject());
    }

    // ─────────────────────────────────────────────────────────────
    // RLS-Aware DataSource Wrapper
    //
    // Intercepta cada conexão emprestada pelo pool e executa:
    //   SET LOCAL app.current_condominium_id = '<uuid>';
    //
    // O valor do UUID vem do JWT já validado, armazenado no
    // SecurityContext como claim "condominiumId" dentro de
    // authentication.getDetails() (Map<String, Object>).
    //
    // SET LOCAL garante que a variável se aplica apenas à transação
    // corrente — ao fazer ROLLBACK ou COMMIT, o PostgreSQL a descarta
    // automaticamente, evitando contaminação entre requests.
    // ─────────────────────────────────────────────────────────────

    public static class RlsAwareDataSource implements DataSource {

        private final DataSource delegate;

        public RlsAwareDataSource(DataSource delegate) {
            this.delegate = delegate;
        }

        @Override
        public Connection getConnection() throws SQLException {
            Connection connection = delegate.getConnection();
            applyRls(connection);
            return connection;
        }

        @Override
        public Connection getConnection(String username, String password) throws SQLException {
            Connection connection = delegate.getConnection(username, password);
            applyRls(connection);
            return connection;
        }

        private void applyRls(Connection connection) throws SQLException {
            String condominiumId = resolveCondominiumId();

            // SET LOCAL tem escopo de transação; SET tem escopo de sessão.
            // Usamos SET LOCAL para garantir limpeza automática ao final de cada transação.
            String sql = (condominiumId != null)
                ? "SET LOCAL app.current_condominium_id = '" + condominiumId + "'"
                : "SET LOCAL app.current_condominium_id = ''";

            try (Statement stmt = connection.createStatement()) {
                stmt.execute(sql);
            }
        }

        /**
         * Extrai o condominiumId do SecurityContext (populado pelo JwtAuthenticationFilter).
         * Retorna null em rotas públicas (login, health check) onde não há autenticação.
         */
        private String resolveCondominiumId() {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

            if (authentication == null || !authentication.isAuthenticated()) {
                return null;
            }

            // O JwtAuthenticationFilter armazena os detalhes do token como
            // um Map<String, Object> em authentication.getDetails().
            Object details = authentication.getDetails();
            if (!(details instanceof Map<?, ?> detailsMap)) {
                return null;
            }

            Object condominiumId = detailsMap.get("condominiumId");
            return condominiumId instanceof String s ? s : null;
        }

        // ── Delegação dos demais métodos da interface DataSource ──

        @Override
        public <T> T unwrap(Class<T> iface) throws SQLException {
            return delegate.unwrap(iface);
        }

        @Override
        public boolean isWrapperFor(Class<?> iface) throws SQLException {
            return delegate.isWrapperFor(iface);
        }

        @Override
        public PrintWriter getLogWriter() throws SQLException {
            return delegate.getLogWriter();
        }

        @Override
        public void setLogWriter(PrintWriter out) throws SQLException {
            delegate.setLogWriter(out);
        }

        @Override
        public void setLoginTimeout(int seconds) throws SQLException {
            delegate.setLoginTimeout(seconds);
        }

        @Override
        public int getLoginTimeout() throws SQLException {
            return delegate.getLoginTimeout();
        }

        @Override
        public Logger getParentLogger() throws SQLFeatureNotSupportedException {
            return delegate.getParentLogger();
        }
    }
}