# Audit Logging Plugin Design Note

## 1. Overview

This document outlines the design and architecture of the Strapi Audit Logging plugin. The plugin provides a comprehensive and automated system for tracking content changes within a Strapi application. It creates a detailed, immutable trail of all Create, Update, and Delete (CUD) operations, giving administrators full visibility into who changed what, and when.

## 2. Goals

-   **Automated Tracking**: Automatically log all CUD events for any content type without manual configuration.
-   **Detailed & Actionable Logs**: Capture essential information for each event, including the content type, record ID, action, timestamp, user, and the data that was changed.
-   **Security**: Ensure that access to audit logs is protected by Strapi's role-based access control (RBAC).
-   **Performance**: The logging mechanism should have minimal impact on application performance, and querying logs should be efficient.
-   **Configurability**: Allow administrators to enable/disable the plugin and exclude specific content types from being logged.
-   **Seamless Integration**: The plugin should integrate smoothly into the Strapi ecosystem, leveraging existing APIs and design patterns.

## 3. Architecture

The Audit Logging plugin is built on Strapi's powerful plugin and lifecycle hook system. It integrates deeply but safely into the application's data layer, ensuring that logging is an automated background process that does not interfere with primary application operations.

### Architectural Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                      │
│  ┌──────────────────┐                          ┌──────────────────┐            │
│  │   User/Admin     │                          │   Admin Panel    │            │
│  │   (REST Client)  │                          │   (Query Logs)   │            │
│  └────────┬─────────┘                          └────────┬─────────┘            │
└───────────┼──────────────────────────────────────────────┼─────────────────────┘
            │                                              │
            │ 1. CRUD Operations                           │ 2. Query Audit Logs
            │ (Create/Update/Delete)                       │
            ▼                                              ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              API LAYER                                       │
│  ┌────────────────────────┐              ┌──────────────────────────────┐    │
│  │   Content API          │              │   Audit Logs API             │    │
│  │   /api/articles        │              │   /audit-logging/audit-logs  │    │
│  └───────────┬────────────┘              └──────────────┬───────────────┘    │
└──────────────┼──────────────────────────────────────────┼────────────────────┘
               │                                          │
               │                                          │
               ▼                                          ▼
┌──────────────────────────────────────────┐   ┌─────────────────────────────┐
│  AUTHENTICATION & AUTHORIZATION          │   │  RBAC POLICY                │
│  admin::isAuthenticatedAdmin             │──▶│  admin::hasPermissions      │
└──────────────┬───────────────────────────┘   └─────────────┬───────────────┘
               │                                             │
               ▼                                             ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                          STRAPI CORE                                      │
│  ┌────────────┐      ┌─────────────┐      ┌──────────────────────────┐    │
│  │   Router   │─────▶│  Controller │─────▶│   Database Layer         │    │
│  │            │      │             │      │   (Entity Service)       │    │
│  └────────────┘      └─────────────┘      └───────────┬──────────────┘    │
│                                                       │                   │
│                                                       │ 3. DB Event       │
│                                                       ▼                   │
│                                          ┌────────────────────────────┐   │
│                                          │  Core Lifecycle Hooks      │   │
│                                          │  afterCreate/Update/Delete │   │
│                                          └──────────┬─────────────────┘   │
└─────────────────────────────────────────────────────┼─────────────────────┘
                                                      │ 4. Event Fired
                                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AUDIT LOGGING PLUGIN                                   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  Bootstrap (bootstrap.ts)                                          │     │
│  │  - Subscribes to lifecycle hooks at startup                        │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  Lifecycle Service (services/lifecycle.ts)                         │     │
│  │                                                                    │     │
│  │  ┌──────────────────────┐     ┌────────────────────────┐           │     │
│  │  │  shouldAuditContent? │────▶│   Extract User ID      │           │     │
│  │  │  (Check exclusions)  │  Y  │   from Request Context │           │     │
│  │  └──────────┬───────────┘     └───────────┬────────────┘           │     │
│  │             │ N                            │                       │     │
│  │             ▼                              ▼                       │     │
│  │          [SKIP]              ┌────────────────────────┐            │     │
│  │                              │  Calculate Changes     │            │     │
│  │                              │  (for UPDATE actions)  │            │     │
│  │                              └───────────┬────────────┘            │     │
│  └──────────────────────────────────────────┼─────────────────────────┘     │
│                                             │ 5. Log Entry Data             │
│                                             ▼                               │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  Audit Log Service (services/audit-log.ts)                         │     │
│  │  - create(): Create new audit log entry                            │     │
│  │  - find(): Query audit logs with filters/pagination                │     │
│  │  - findOne(): Get single audit log by ID                           │     │
│  └──────────────────────────────┬─────────────────────────────────────┘     │
│                                 │                                           │
│  ┌──────────────────────────────┴─────────────────────────────────────┐    │
│  │  Audit Controller (controllers/audit-log.ts)                       │    │
│  │  - Exposes audit log service via REST API                          │    │
│  │  - Handles HTTP requests/responses                                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      │ 6. INSERT/SELECT
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATA LAYER                                         │
│  ┌────────────────────────┐              ┌──────────────────────────────┐  │
│  │   Content Tables       │              │   audit_logs Table           │  │
│  │   (articles, etc.)     │              │   ┌──────────────────────┐   │  │
│  │                        │              │   │ Indexes:             │   │  │
│  │                        │              │   │ - contentType        │   │  │
│  │                        │              │   │ - userId             │   │  │
│  │                        │              │   │ - action             │   │  │
│  │                        │              │   │ - timestamp          │   │  │
│  │                        │              │   │ - composite (ct,a,t) │   │  │
│  │                        │              │   └──────────────────────┘   │  │
│  └────────────────────────┘              └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Flow Description

1. **User Action**: A user performs a CRUD operation (Create, Update, Delete) on content through the Content API or Admin Panel.
2. **Database Operation**: The request goes through authentication, routing, and controller layers, eventually reaching the Database Layer.
3. **Lifecycle Event**: After the database operation completes, Strapi's core lifecycle hooks fire the appropriate event (`afterCreate`, `afterUpdate`, or `afterDelete`).
4. **Event Interception**: The Audit Logging plugin's Lifecycle Service, which subscribed during bootstrap, intercepts the event.
5. **Audit Processing**: The service checks if the content type should be audited, extracts user context, calculates changes (for updates), and formats the log entry.
6. **Log Storage**: The Audit Log Service persists the entry to the `audit_logs` table with optimized indexes.
7. **Query Access**: Administrators can query audit logs through the secure Audit API, which enforces authentication and RBAC policies.

### Components

1.  **Lifecycle Hooks Subscription (`bootstrap.ts`)**: When Strapi starts, the plugin's `bootstrap` function subscribes to the core database lifecycle events (`afterCreate`, `afterUpdate`, `afterDelete`, etc.). This is the entry point for the logging mechanism.

2.  **Event Handling (`services/lifecycle.ts`)**: A dedicated `lifecycle` service intercepts these events. It contains the core logic to:
    -   Check if a given content type should be audited based on the plugin's configuration.
    -   Extract relevant context, such as the user who initiated the action, the content type, and the data involved.
    -   For `update` events, it calculates the changed fields.
    -   Pass the processed information to the `audit-log` service.

3.  **Log Persistence (`services/audit-log.ts`)**: The `audit-log` service is responsible for creating a new entry in the `audit_logs` database table. It abstracts the database query logic for creating and retrieving logs.

4.  **Data Model (`content-types/audit-log.ts`)**: The plugin defines a dedicated `audit-log` collection type. The schema includes fields for `contentType`, `recordId`, `action`, `timestamp`, `userId`, `changes` (for updates), and `payload` (for creates/deletes). The schema also defines several database indexes on key fields to ensure fast and efficient querying.

5.  **Secure API Endpoint (`routes/index.ts`, `controllers/audit-log.ts`)**: The plugin exposes a secure, read-only REST API (`/audit-logging/audit-logs`). This endpoint allows administrators with the correct permissions to query the `audit_logs` table with support for filtering, sorting, and pagination. Access is controlled by Strapi's `admin::hasPermissions` policy.

## 4. Data Schema

The `audit_logs` collection type has the following key attributes:

-   `contentType` (string): The UID of the content type that was modified (e.g., `api::article.article`).
-   `recordId` (string): The ID of the record that was affected.
-   `action` (enum): The action performed (`create`, `update`, `delete`).
-   `timestamp` (datetime): The timestamp of when the event occurred.
-   `userId` (integer): The ID of the admin user who performed the action.
-   `changes` (json): For `update` actions, a JSON object containing only the fields that were changed.
-   `payload` (json): For `create` and `delete` actions, the full data payload of the record.

### Database Indexes

To optimize query performance, the following indexes are created on the `audit_logs` table:
-   `contentType`
-   `userId`
-   `action`
-   `timestamp`
-   A composite index on (`contentType`, `action`, `timestamp`)

## 5. Security

-   **Permissions**: The plugin registers a `plugin::audit-logging.read` permission. Administrators must have this permission assigned to their role to access the audit log API.
-   **Authentication**: All API routes are protected by the `admin::isAuthenticatedAdmin` policy, ensuring that only authenticated admin users can access them.
-   **Read-Only API**: The public-facing API is read-only, preventing any unauthorized modification of the audit trail.

## 6. Configuration

The plugin can be configured in `config/plugins.js`:

```javascript
module.exports = {
  'audit-logging': {
    // Enable or disable the plugin
    enabled: true,
    config: {
      // Exclude specific content types from being logged
      excludeContentTypes: [
        'api::temp-record.temp-record',
        'plugin::users-permissions.permission',
      ],
    },
  },
};
```

This design ensures that the Audit Logging plugin is a robust, secure, and performant solution for tracking content changes in Strapi, providing a solid foundation for compliance and accountability.
