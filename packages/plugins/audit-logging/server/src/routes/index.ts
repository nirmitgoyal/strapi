const adminRoutes = {
  type: 'admin' as const,
  routes: [
    {
      method: 'GET',
      path: '/audit-logs',
      handler: 'audit-log.find',
      config: {
        policies: [
          'admin::isAuthenticatedAdmin',
          {
            name: 'admin::hasPermissions',
            config: { actions: ['plugin::audit-logging.read'] }
          }
        ]
      }
    },
    {
      method: 'GET',
      path: '/audit-logs/:id',
      handler: 'audit-log.findOne',
      config: {
        policies: [
          'admin::isAuthenticatedAdmin',
          {
            name: 'admin::hasPermissions',
            config: { actions: ['plugin::audit-logging.read'] }
          }
        ]
      }
    },
    {
      method: 'GET',
      path: '/audit-logs/stats',
      handler: 'audit-log.getStats',
      config: {
        policies: [
          'admin::isAuthenticatedAdmin',
          {
            name: 'admin::hasPermissions',
            config: { actions: ['plugin::audit-logging.read'] }
          }
        ]
      }
    }
  ],
};

export const routes = {
  admin: adminRoutes,
};
