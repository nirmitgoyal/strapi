import type { Core } from '@strapi/types';
import { createLifecycleSubscriber } from './services/lifecycle';
import { getPluginConfig } from './utils/config';

/**
 * Bootstrap function called when the plugin is loaded
 * Registers database lifecycle hooks to capture content changes
 */
export default ({ strapi }: { strapi: Core.Strapi }) => {
  const { enabled, excludeContentTypes } = getPluginConfig(strapi);

  if (!enabled) {
    strapi.log.info('Audit Logging plugin: Disabled by configuration');
    return;
  }

  // Subscribe to database lifecycle events
  const subscriber = createLifecycleSubscriber(strapi);
  strapi.db.lifecycles.subscribe(subscriber);

  // Log configuration info
  if (excludeContentTypes.length > 0) {
    strapi.log.info(
      `Audit Logging plugin: Lifecycle hooks registered. Excluded content types: ${excludeContentTypes.join(', ')}`
    );
  } else {
    strapi.log.info('Audit Logging plugin: Lifecycle hooks registered successfully');
  }
};
