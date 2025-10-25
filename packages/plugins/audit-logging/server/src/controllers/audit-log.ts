import type { Core } from '@strapi/types';
import type { Context } from 'koa';

export default ({ strapi }: { strapi: Core.Strapi }) => ({
  /**
   * GET /audit-logs
   * Find audit logs with filters and pagination
   */
  async find(ctx: Context) {
    try {
      const service = strapi.plugin('audit-logging').service('audit-log');

      // Transform Strapi query format to database query
      const query = strapi.get('query-params').transform(
        'plugin::audit-logging.audit-log',
        ctx.query
      );

      const result = await service.find(query);

      ctx.body = result;
    } catch (error) {
      strapi.log.error('Controller error in find:', error);
      ctx.throw(500, 'Failed to fetch audit logs');
    }
  },

  /**
   * GET /audit-logs/:id
   * Get a single audit log by ID
   */
  async findOne(ctx: Context) {
    try {
      const { id } = ctx.params;
      const service = strapi.plugin('audit-logging').service('audit-log');

      const auditLog = await service.findOne(id);

      if (!auditLog) {
        return ctx.notFound('Audit log not found');
      }

      ctx.body = { data: auditLog };
    } catch (error) {
      strapi.log.error('Controller error in findOne:', error);
      ctx.throw(500, 'Failed to fetch audit log');
    }
  },

  /**
   * GET /audit-logs/stats
   * Get statistics about audit logs
   */
  async getStats(ctx: Context) {
    try {
      const service = strapi.plugin('audit-logging').service('audit-log');
      const stats = await service.getStats();

      ctx.body = { data: stats };
    } catch (error) {
      strapi.log.error('Controller error in getStats:', error);
      ctx.throw(500, 'Failed to fetch audit log statistics');
    }
  },
});
