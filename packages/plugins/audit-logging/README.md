# Strapi Audit Logging Plugin

## 1. Overview

The Audit Logging plugin for Strapi provides a comprehensive and automated system for tracking content changes within your application. It creates a detailed, immutable trail of all Create, Update, and Delete (CUD) operations, giving you full visibility into who changed what, and when.

This plugin is designed to be non-intrusive, highly performant, and seamlessly integrated into the Strapi ecosystem, making it an essential tool for applications requiring security, compliance, and accountability.

## 2. Features

- **Automatic Logging**: Automatically logs all `create`, `update`, and `delete` events for any content type.
- **Detailed Log Entries**: Captures essential information for each event, including:
  - The content type being modified.
  - The specific record ID.
  - The action performed (`create`, `update`, `delete`).
  - A precise timestamp.
  - The authenticated admin user who performed the action.
  - The changed data for `update` actions and the full data payload for `create` and `delete` actions.
- **Secure by Default**: Access to audit logs is protected by Strapi's role-based access control (RBAC). Only administrators with the appropriate permissions can view the logs.
- **Highly Configurable**:
  - Easily enable or disable the plugin globally.
  - Exclude specific content types from being logged to reduce noise.
- **Optimized for Performance**: Uses database indexes on key fields to ensure that querying audit logs is fast and efficient, even with a large volume of data.
- **REST API**: A dedicated, secure REST API endpoint (`/audit-logging/audit-logs`) for retrieving and filtering audit logs.

## 3. Architectural Overview

The Audit Logging plugin is built on Strapi's powerful plugin and lifecycle hook system. It integrates deeply but safely into the application's data layer.

1.  **Lifecycle Hooks**: The plugin subscribes to Strapi's core database lifecycle events (`afterCreate`, `afterUpdate`, `afterDelete`). When you create, update, or delete an entry for any content type, these hooks are triggered.
2.  **Event Handling Service**: A dedicated `lifecycle` service intercepts these events. It gathers relevant context, such as the user who initiated the action, the content type, and the data involved.
3.  **Audit Log Service**: The `lifecycle` service then passes this information to the `audit-log` service, which is responsible for creating a new entry in the `audit_logs` database table.
4.  **Database Storage**: The audit log entry is stored in a dedicated `audit_logs` collection type, which is optimized with database indexes for fast retrieval.
5.  **API Endpoint**: The plugin exposes a secure, read-only REST API. This endpoint allows administrators to query the `audit_logs` table with support for filtering, sorting, and pagination.

This architecture ensures that audit logging is an automated and background process that does not interfere with your application's primary operations.

## 4. Implementation Details

### Core Components

- **Content Type (`./server/src/content-types/audit-log.ts`)**: Defines the schema for the `audit_logs` table. It includes fields for `contentType`, `recordId`, `action`, `timestamp`, `userId`, `changes` (for updates), and `payload` (for creates/deletes). It also defines five database indexes to optimize query performance.

- **Bootstrap (`./server/src/bootstrap.ts`)**: This file is executed when Strapi starts. It checks the plugin's configuration and, if enabled, subscribes to the database lifecycle events using `strapi.db.lifecycles.subscribe()`.

- **Lifecycle Service (`./server/src/services/lifecycle.ts`)**: This is the heart of the logging mechanism.
  - It contains the logic that runs after a database event occurs.
  - It checks if a given content type should be audited based on the plugin's configuration (`excludeContentTypes` and built-in rules).
  - It extracts the user ID from the request context.
  - It calls the `audit-log` service to create the log entry.

- **Audit Log Service (`./server/src/services/audit-log.ts`)**: Provides helper functions for managing audit logs.
  - `create()`: Creates a new audit log entry in the database.
  - `find()`: Retrieves a paginated and filterable list of audit logs.
  - `findOne()`: Retrieves a single audit log by its ID.

- **Controller (`./server/src/controllers/audit-log.ts`)**: Exposes the `audit-log` service's methods to the REST API. It handles incoming HTTP requests, calls the appropriate service function, and sends back the response.

- **Routes (`./server/src/routes/index.ts`)**: Defines the API routes for the plugin, such as `GET /audit-logging/audit-logs`. It also applies the necessary authentication and authorization policies to secure the endpoints.

- **Permissions (`./server/src/register.ts`)**: Registers the `plugin::audit-logging.read` permission, allowing Strapi administrators to grant access to the audit logs on a per-role basis.

### How to Use

1.  **Enable the Plugin**:
    In your `config/plugins.js` file, enable the plugin:
    ```javascript
    module.exports = {
      // ...
      'audit-logging': {
        enabled: true,
      },
      // ...
    };
    ```

2.  **Exclude Content Types (Optional)**:
    To prevent certain content types from being logged, add them to the `excludeContentTypes` array:
    ```javascript
    'audit-logging': {
      enabled: true,
      config: {
        excludeContentTypes: [
          'api::temp-record.temp-record',
          'plugin::users-permissions.permission',
        ],
      },
    },
    ```

3.  **Set Permissions**:
    - Go to `Settings` -> `Administration Panel` -> `Roles`.
    - Select a role (e.g., Editor).
    - Under the `Plugins` section, find `Audit Logging` and check the `Read` permission.
    - Save the role. Users with this role will now be able to view the audit logs.

4.  **Running the `getstarted` Example**

    To see the Audit Logging plugin in action, you can run the `getstarted` example application included in the Strapi monorepo.

    1.  **Navigate to the root of the Strapi project.**

    2.  **Install dependencies and build the project:**
        ```bash
        yarn install
        yarn build
        ```

    3.  **Navigate to the example project:**
        ```bash
        cd examples/getstarted
        ```

    4.  **Run the development server:**
        ```bash
        yarn develop
        ```
        This will start the Strapi server for the `getstarted` application, with the Audit Logging plugin enabled. You can then perform CRUD operations and see the audit logs being created.

5.  **View Audit Logs via API**:

    You can fetch audit logs via the REST API.

    #### Obtain the JWT token
    ```bash
    JWT=$(curl -s -X POST http://localhost:1337/admin/login \
      -H "Content-Type: application/json" \
      -d '{"email":"nirmitgoyal.goyal@gmail.com","password":"PassworD@1"}' \
      | jq -r '.data.token')
    ```

    #### Get all the audit data using the highest level API:
    ```bash
    curl -H "Authorization: Bearer $JWT" http://localhost:1337/audit-logging/audit-logs 2>/dev/null | jq '.'
    ```