import type { Core } from '@strapi/types';
import { createLifecycleSubscriber } from './services/lifecycle';

/**
 * Bootstrap function called when the plugin is loaded
 * Registers database lifecycle hooks to capture content changes
 */
export default ({ strapi }: { strapi: Core.Strapi }) => {
  // Get plugin configuration
  const pluginConfig = strapi.config.get('plugin::audit-logging') as {
    enabled?: boolean;
    config?: {
      excludeContentTypes?: string[];
    };
  };

  // Check if audit logging is enabled (default: true if not explicitly set to false)
  const isEnabled = pluginConfig?.enabled !== false;

  if (!isEnabled) {
    strapi.log.info('Audit Logging plugin: Disabled by configuration');
    return;
  }

  // Subscribe to database lifecycle events
  const subscriber = createLifecycleSubscriber(strapi);
  strapi.db.lifecycles.subscribe(subscriber);

  // Log configuration info
  const excludeList = pluginConfig?.config?.excludeContentTypes || [];
  if (excludeList.length > 0) {
    strapi.log.info(
      `Audit Logging plugin: Lifecycle hooks registered. Excluded content types: ${excludeList.join(', ')}`
    );
  } else {
    strapi.log.info('Audit Logging plugin: Lifecycle hooks registered successfully');
  }
};
