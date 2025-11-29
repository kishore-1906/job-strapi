module.exports = ({ env }) => ({
  connection: {
    client: env('DATABASE_CLIENT', 'postgres'),
    connection: {
      host: env('DATABASE_HOST', '127.0.0.1'),
      port: env.int('DATABASE_PORT', 5432),
      database: env('DATABASE_NAME', 'strapidb'),
      user: env('DATABASE_USERNAME', 'strapiuser'),
      password: env('DATABASE_PASSWORD', 'password'),
      ssl: false,
    },
  },
});

