import type { Core } from '@strapi/types';

export interface AuditLogData {
  contentType: string;
  recordId: string;
  action: 'create' | 'update' | 'delete';
  timestamp: Date | string;
  userId?: number;
  changes?: Record<string, unknown> | null;
  payload?: Record<string, unknown> | null;
}

interface AdminUser {
  id: number;
  firstname?: string | null;
  lastname?: string | null;
  username?: string | null;
  email?: string | null;
}

const AUDIT_LOG_UID = 'plugin::audit-logging.audit-log';
const AUDIT_LOG_TABLE = 'audit_logs';

const normalizeTimestamp = (value: Date | string): string =>
  value instanceof Date ? value.toISOString() : value;

const buildUserDisplayName = (user?: AdminUser | null): string => {
  if (!user) {
    return 'Unknown User';
  }

  const parts = [user.firstname, user.lastname].filter(Boolean);

  if (parts.length > 0) {
    return parts.join(' ');
  }

  if (user.username) {
    return user.username;
  }

  if (user.email) {
    return user.email;
  }

  return 'Unknown User';
};

const formatLog = (log: any, userDisplayName: string) => {
  const base = {
    id: log.id,
    contentType: log.contentType,
    recordId: log.recordId,
    action: log.action,
    timestamp: log.timestamp instanceof Date ? log.timestamp.toISOString() : log.timestamp,
    userDisplayName,
  };

  if (log.action === 'create' || log.action === 'delete') {
    return {
      ...base,
      ...(log.payload != null ? { payload: log.payload } : {}),
    };
  }

  return {
    ...base,
    ...(log.changes != null ? { changedFields: log.changes } : {}),
  };
};

const toUniqueNumericIds = (ids: Array<number | null | undefined>) => {
  const seen = new Set<number>();
  const result: number[] = [];

  ids.forEach((id) => {
    if (typeof id === 'number' && Number.isFinite(id) && !seen.has(id)) {
      seen.add(id);
      result.push(id);
    }
  });

  return result;
};

/**
 * Service for managing audit logs
 * Handles creation and querying of audit log entries
 */
export default ({ strapi }: { strapi: Core.Strapi }) => {
  const fetchUserDisplayNameMap = async (userIds: number[]) => {
    if (userIds.length === 0) {
      return new Map<number, string>();
    }

    try {
      const users = await strapi.db.query('admin::user').findMany({
        where: {
          id: {
            $in: userIds,
          },
        },
        select: ['id', 'firstname', 'lastname', 'username', 'email'],
      });

      return users.reduce<Map<number, string>>((acc, user: AdminUser) => {
        acc.set(user.id, buildUserDisplayName(user));
        return acc;
      }, new Map());
    } catch (error) {
      strapi.log.warn('Failed to fetch admin users for audit logs:', error);
      return new Map<number, string>();
    }
  };

  return {
    /**
     * Create a new audit log entry
     */
    async create(data: AuditLogData) {
      try {
        const auditLog = await strapi.db.query(AUDIT_LOG_UID).create({
          data: {
            contentType: data.contentType,
            recordId: String(data.recordId),
            action: data.action,
            timestamp: normalizeTimestamp(data.timestamp),
            userId: data.userId ?? null,
            changes: data.changes ?? null,
            payload: data.payload ?? null,
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
        const orderBy = query.orderBy || { timestamp: 'desc' };

        const { results, pagination } = await strapi.db.query(AUDIT_LOG_UID).findPage({
          ...query,
          orderBy,
        });

        const userIdList = toUniqueNumericIds(results.map((log: any) => log.userId));
        const userDisplayMap = await fetchUserDisplayNameMap(userIdList);

        const formattedResults = results.map((log: any) => {
          const displayName = userDisplayMap.get(log.userId) ?? 'Unknown User';
          return formatLog(log, displayName);
        });

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
        const log = await strapi.db.query(AUDIT_LOG_UID).findOne({
          where: { id },
        });

        if (!log) {
          return null;
        }

        let userDisplayName = 'Unknown User';

        if (typeof log.userId === 'number') {
          try {
            const user = await strapi.db.query('admin::user').findOne({
              where: { id: log.userId },
              select: ['id', 'firstname', 'lastname', 'username', 'email'],
            });

            userDisplayName = buildUserDisplayName(user as AdminUser | null);
          } catch (error) {
            strapi.log.warn(`Failed to fetch user ${log.userId}:`, error);
          }
        }

        return formatLog(log, userDisplayName);
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
        const deleted = await strapi.db
          .connection(AUDIT_LOG_TABLE)
          .where('timestamp', '<', normalizeTimestamp(date))
          .delete();

        return { deleted };
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
        const total = await strapi.db.query(AUDIT_LOG_UID).count();

        const knex = strapi.db.connection;

        const actionRows = await knex(AUDIT_LOG_TABLE)
          .select('action')
          .count({ count: '*' })
          .groupBy('action');

        const contentTypeRows = await knex(AUDIT_LOG_TABLE)
          .select('content_type as contentType')
          .count({ count: '*' })
          .groupBy('content_type')
          .orderBy('count', 'desc')
          .limit(10);

        const mapCount = (row: Record<string, unknown>) => ({
          ...row,
          count: Number(row.count),
        });

        return {
          total,
          byAction: actionRows.map(mapCount),
          topContentTypes: contentTypeRows.map(mapCount),
        };
      } catch (error) {
        strapi.log.error('Failed to get audit log stats:', error);
        throw error;
      }
    },
  };
};
