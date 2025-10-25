import type { Core } from '@strapi/types';

export interface AuditLogData {
  contentType: string;
  recordId: string;
  action: 'create' | 'update' | 'delete';
  timestamp: Date;
  userId?: number;
  changes?: Record<string, any>;
  payload?: Record<string, any>;
}

/**
 * Service for managing audit logs
 * Handles creation and querying of audit log entries
 */
export default ({ strapi }: { strapi: Core.Strapi }) => ({
  /**
   * Create a new audit log entry
   */
  async create(data: AuditLogData) {
    try {
      const auditLog = await strapi.db.query('plugin::audit-logging.audit-log').create({
        data: {
          contentType: data.contentType,
          recordId: String(data.recordId),
          action: data.action,
          timestamp: data.timestamp,
          userId: data.userId || null,
          changes: data.changes || null,
          payload: data.payload || null,
        },
      });

      return auditLog;
    } catch (error) {
      strapi.log.error('Failed to create audit log:', error);
      throw error;
    }
  },

  /**
   * Find audit logs with filters and pagination
   * Supports sorting via query params (e.g., sort=timestamp:desc,action:asc)
   */
  async find(query: any) {
    try {
      // Use provided orderBy from query, or default to timestamp descending
      const orderBy = query.orderBy || { timestamp: 'desc' };

      const { results, pagination } = await strapi.db
        .query('plugin::audit-logging.audit-log')
        .findPage({
          ...query,
          orderBy,
        });

      // Format the results to only include the required fields
      const formattedResults = await Promise.all(
        results.map(async (log: any) => {
          let userDisplayName = 'Unknown User';
          
          if (log.userId) {
            try {
              const user = await strapi.db.query('admin::user').findOne({
                where: { id: log.userId },
                select: ['firstname', 'lastname', 'username', 'email'],
              });
              
              if (user) {
                if (user.firstname || user.lastname) {
                  userDisplayName = [user.firstname, user.lastname].filter(Boolean).join(' ');
                } else if (user.username) {
                  userDisplayName = user.username;
                } else if (user.email) {
                  userDisplayName = user.email;
                }
              }
            } catch (error) {
              strapi.log.warn(`Failed to fetch user ${log.userId}:`, error);
            }
          }

          return {
            contentType: log.contentType,
            recordId: log.recordId,
            action: log.action,
            timestamp: log.timestamp,
            userDisplayName,
            ...(log.action === 'create' || log.action === 'delete'
              ? { payload: log.payload }
              : { changedFields: log.changes }),
          };
        })
      );

      return {
        data: formattedResults,
        meta: {
          pagination,
        },
      };
    } catch (error) {
      strapi.log.error('Failed to find audit logs:', error);
      throw error;
    }
  },

  /**
   * Find a single audit log by ID
   */
  async findOne(id: number | string) {
    try {
      const log = await strapi.db.query('plugin::audit-logging.audit-log').findOne({
        where: { id },
      });

      if (!log) {
        return null;
      }

      let userDisplayName = 'Unknown User';
      
      if (log.userId) {
        try {
          const user = await strapi.db.query('admin::user').findOne({
            where: { id: log.userId },
            select: ['firstname', 'lastname', 'username', 'email'],
          });
          
          if (user) {
            if (user.firstname || user.lastname) {
              userDisplayName = [user.firstname, user.lastname].filter(Boolean).join(' ');
            } else if (user.username) {
              userDisplayName = user.username;
            } else if (user.email) {
              userDisplayName = user.email;
            }
          }
        } catch (error) {
          strapi.log.warn(`Failed to fetch user ${log.userId}:`, error);
        }
      }

      return {
        contentType: log.contentType,
        recordId: log.recordId,
        action: log.action,
        timestamp: log.timestamp,
        userDisplayName,
        ...(log.action === 'create' || log.action === 'delete'
          ? { payload: log.payload }
          : { changedFields: log.changes }),
      };
    } catch (error) {
      strapi.log.error('Failed to find audit log:', error);
      throw error;
    }
  },

  /**
   * Delete old audit logs (for cleanup/retention policies)
   */
  async deleteOlderThan(date: Date) {
    try {
      const result = await strapi.db.query('plugin::audit-logging.audit-log').deleteMany({
        where: {
          timestamp: {
            $lt: date.toISOString(),
          },
        },
      });

      return result;
    } catch (error) {
      strapi.log.error('Failed to delete old audit logs:', error);
      throw error;
    }
  },

  /**
   * Get statistics about audit logs
   */
  async getStats() {
    try {
      const total = await strapi.db.query('plugin::audit-logging.audit-log').count();

      const byAction = await strapi.db.connection.raw(`
        SELECT action, COUNT(*) as count
        FROM audit_logs
        GROUP BY action
      `);

      const byContentType = await strapi.db.connection.raw(`
        SELECT content_type, COUNT(*) as count
        FROM audit_logs
        GROUP BY content_type
        ORDER BY count DESC
        LIMIT 10
      `);

      return {
        total,
        byAction: byAction.rows,
        topContentTypes: byContentType.rows,
      };
    } catch (error) {
      strapi.log.error('Failed to get audit log stats:', error);
      throw error;
    }
  },
});
