import type { Schema } from '@strapi/types';

export const auditLog = {
  kind: 'collectionType' as const,
  collectionName: 'audit_logs',
  info: {
    singularName: 'audit-log',
    pluralName: 'audit-logs',
    displayName: 'Audit Log',
    description: 'Automated audit log for content changes',
  },
  options: {
    draftAndPublish: false,
  },
  pluginOptions: {
    'content-manager': {
      visible: true,
    },
    'content-type-builder': {
      visible: false,
    },
  },
  attributes: {
    contentType: {
      type: 'string',
      required: true,
    },
    recordId: {
      type: 'string',
      required: true,
    },
    action: {
      type: 'enumeration',
      enum: ['create', 'update', 'delete'],
      required: true,
    },
    timestamp: {
      type: 'datetime',
      required: true,
    },
    userId: {
      type: 'integer',
    },
    changes: {
      type: 'json',
    },
    payload: {
      type: 'json',
    },
  },
  // adding indexes
  indexes: [
    {
      name: 'audit_logs_content_type_index',
      columns: ['content_type'],
    },
    {
      name: 'audit_logs_user_id_index',
      columns: ['user_id'],
    },
    {
      name: 'audit_logs_action_index',
      columns: ['action'],
    },
    {
      name: 'audit_logs_timestamp_index',
      columns: ['timestamp'],
    },
    {
      name: 'audit_logs_composite_index',
      columns: ['content_type', 'action', 'timestamp'],
    },
  ],
};
