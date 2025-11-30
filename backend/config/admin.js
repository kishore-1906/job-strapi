module.exports = ({ env }) => ({
  auth: {
    secret: env('ADMIN_AUTH_SECRET'),
  },
});

