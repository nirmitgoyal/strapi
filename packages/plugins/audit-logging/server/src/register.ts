import type { Core } from '@strapi/types';

/**
 * Register function called when the plugin is registered
 * Used for any initialization that needs to happen before bootstrap
 */
export default ({ strapi }: { strapi: Core.Strapi }) => {
  // Register permission actions for the plugin
  strapi.admin?.services.permission.actionProvider.registerMany([
    {
      section: 'plugins',
      displayName: 'Read',
      uid: 'read',
      pluginName: 'audit-logging',
    },
  ]);

  strapi.log.info('Audit Logging plugin: Registering plugin and permissions');
};
