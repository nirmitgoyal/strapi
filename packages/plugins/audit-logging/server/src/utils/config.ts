import type { Core } from '@strapi/types';

export interface NormalizedPluginConfig {
  enabled: boolean;
  excludeContentTypes: string[];
}

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/**
 * Read and normalize the plugin configuration.
 * Ensures boolean shortcuts (e.g. `false`) are honoured and default values applied.
 */
export const getPluginConfig = (strapi: Core.Strapi): NormalizedPluginConfig => {
  const rawConfig = strapi.config.get('plugin::audit-logging');

  if (rawConfig === false) {
    return {
      enabled: false,
      excludeContentTypes: [],
    };
  }

  const configObject = isPlainObject(rawConfig) ? rawConfig : {};
  const nestedConfig = isPlainObject(configObject.config) ? configObject.config : {};

  return {
    enabled: configObject.enabled !== false,
    excludeContentTypes: Array.isArray(nestedConfig.excludeContentTypes)
      ? nestedConfig.excludeContentTypes
      : [],
  };
};

