import type { Core } from '@strapi/types';
import type { Event } from '@strapi/database/dist/lifecycles';

/**
 * Calculate changes between old and new data for update operations
 */
const calculateChanges = (params: any): Record<string, any> | null => {
  if (!params.data) {
    return null;
  }

  // For updates, we can see what fields are being changed
  const changes: Record<string, any> = {};
  
  Object.keys(params.data).forEach((key) => {
    // Skip internal fields and relations
    if (!key.startsWith('_') && key !== 'id') {
      changes[key] = params.data[key];
    }
  });

  return Object.keys(changes).length > 0 ? changes : null;
};

/**
 * Get user ID from request context
 */
const getUserId = (strapi: Core.Strapi): number | undefined => {
  try {
    const requestState = strapi.requestContext.get()?.state;
    return requestState?.user?.id;
  } catch (error) {
    return undefined;
  }
};

/**
 * Check if a content type should be audited
 * Skip internal Strapi content types and the audit log itself
 */
const shouldAuditContentType = (uid: string, strapi: Core.Strapi): boolean => {
  // Get plugin configuration
  const pluginConfig = strapi.config.get('plugin::audit-logging') as {
    enabled?: boolean;
    config?: {
      excludeContentTypes?: string[];
    };
  };

  // Check if logging is globally enabled (default: true)
  if (pluginConfig?.enabled === false) {
    return false;
  }

  // Check if content type is in the exclusion list
  const excludeList = pluginConfig?.config?.excludeContentTypes || [];
  if (excludeList.includes(uid)) {
    return false;
  }

  // Skip internal Strapi types
  if (uid.startsWith('admin::')) {
    return false;
  }
  
  if (uid.startsWith('strapi::')) {
    return false;
  }
  
  // Skip the audit log itself to avoid infinite loops
  if (uid === 'plugin::audit-logging.audit-log') {
    return false;
  }

  // Skip upload plugin files by default (can generate too many logs)
  if (uid === 'plugin::upload.file' || uid === 'plugin::upload.folder') {
    return false;
  }

  return true;
};

/**
 * Create lifecycle subscriber for database events
 */
export const createLifecycleSubscriber = (strapi: Core.Strapi) => {
  return {
    /**
     * After a record is created
     */
    async afterCreate(event: Event) {
      const { model, params, result } = event;

      if (!shouldAuditContentType(model.uid, strapi)) {
        return;
      }

      try {
        const service = strapi.plugin('audit-logging').service('audit-log');
        
        await service.create({
          contentType: model.uid,
          recordId: result?.id || result?.documentId || 'unknown',
          action: 'create',
          timestamp: new Date(),
          userId: getUserId(strapi),
          payload: params.data,
        });
      } catch (error) {
        strapi.log.error('Failed to create audit log for create action:', error);
      }
    },

    /**
     * After a record is updated
     */
    async afterUpdate(event: Event) {
      const { model, params, result } = event;

      if (!shouldAuditContentType(model.uid, strapi)) {
        return;
      }

      try {
        const service = strapi.plugin('audit-logging').service('audit-log');
        const changes = calculateChanges(params);

        await service.create({
          contentType: model.uid,
          recordId: result?.id || result?.documentId || params.where?.id || 'unknown',
          action: 'update',
          timestamp: new Date(),
          userId: getUserId(strapi),
          changes,
          payload: params.data,
        });
      } catch (error) {
        strapi.log.error('Failed to create audit log for update action:', error);
      }
    },

    /**
     * After a record is deleted
     */
    async afterDelete(event: Event) {
      const { model, params, result } = event;

      if (!shouldAuditContentType(model.uid, strapi)) {
        return;
      }

      try {
        const service = strapi.plugin('audit-logging').service('audit-log');

        await service.create({
          contentType: model.uid,
          recordId: result?.id || result?.documentId || params.where?.id || 'unknown',
          action: 'delete',
          timestamp: new Date(),
          userId: getUserId(strapi),
          payload: params.where,
        });
      } catch (error) {
        strapi.log.error('Failed to create audit log for delete action:', error);
      }
    },

    /**
     * After multiple records are created
     */
    async afterCreateMany(event: Event) {
      const { model, params, result } = event;

      if (!shouldAuditContentType(model.uid, strapi)) {
        return;
      }

      try {
        const service = strapi.plugin('audit-logging').service('audit-log');
        const records = Array.isArray(result) ? result : [result];

        // Create audit log for each created record
        for (const record of records) {
          await service.create({
            contentType: model.uid,
            recordId: record?.id || record?.documentId || 'unknown',
            action: 'create',
            timestamp: new Date(),
            userId: getUserId(strapi),
            payload: params.data,
          });
        }
      } catch (error) {
        strapi.log.error('Failed to create audit logs for createMany action:', error);
      }
    },

    /**
     * After multiple records are updated
     */
    async afterUpdateMany(event: Event) {
      const { model, params } = event;

      if (!shouldAuditContentType(model.uid, strapi)) {
        return;
      }

      try {
        const service = strapi.plugin('audit-logging').service('audit-log');
        const changes = calculateChanges(params);

        // For bulk updates, we log a single entry indicating a bulk operation
        await service.create({
          contentType: model.uid,
          recordId: 'bulk',
          action: 'update',
          timestamp: new Date(),
          userId: getUserId(strapi),
          changes,
          payload: {
            where: params.where,
            data: params.data,
          },
        });
      } catch (error) {
        strapi.log.error('Failed to create audit log for updateMany action:', error);
      }
    },

    /**
     * After multiple records are deleted
     */
    async afterDeleteMany(event: Event) {
      const { model, params } = event;

      if (!shouldAuditContentType(model.uid, strapi)) {
        return;
      }

      try {
        const service = strapi.plugin('audit-logging').service('audit-log');

        // For bulk deletes, we log a single entry indicating a bulk operation
        await service.create({
          contentType: model.uid,
          recordId: 'bulk',
          action: 'delete',
          timestamp: new Date(),
          userId: getUserId(strapi),
          payload: {
            where: params.where,
          },
        });
      } catch (error) {
        strapi.log.error('Failed to create audit log for deleteMany action:', error);
      }
    },
  };
};
