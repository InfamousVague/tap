import React from 'react';
import { ScrollView, RefreshControl } from 'react-native';
import {
  ThemeProvider,
  useTheme,
  Card,
  Text,
  HStack,
  VStack,
  Indicator,
  Badge,
  Skeleton,
  icons,
  Icon,
} from '@mattssoftware/base-rn';
import { useQuery } from '../hooks/useApi';
import { api, Server } from '../services/api';

export function HomeScreen() {
  const { colors, spacing } = useTheme();
  const { data: servers, loading, refetch } = useQuery(() => api.listServers());

  const upCount = servers?.filter(s => s.status === 'up').length ?? 0;
  const totalCount = servers?.length ?? 0;
  const downServers = servers?.filter(s => s.status !== 'up') ?? [];

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[4] }}
      refreshControl={
        <RefreshControl refreshing={loading} onRefresh={refetch} tintColor={colors.accent} />
      }
    >
      {/* Status Overview */}
      <Card variant="filled" padding="md">
        <HStack gap={3} align="center">
          <Icon svg={icons.activity} size={24} color={colors.accent} />
          <VStack gap={0.5}>
            <Text variant="title">
              {loading ? '...' : `${upCount}/${totalCount} Servers Online`}
            </Text>
            {downServers.length > 0 && (
              <Text variant="caption" color={colors.error}>
                {downServers.map(s => s.name).join(', ')} down
              </Text>
            )}
          </VStack>
        </HStack>
      </Card>

      {/* Server Grid */}
      <Text variant="label" color={colors.textSubtle}>Servers</Text>

      {loading && !servers ? (
        <VStack gap={3}>
          <Skeleton height={80} />
          <Skeleton height={80} />
          <Skeleton height={80} />
        </VStack>
      ) : (
        <VStack gap={3}>
          {servers?.map(server => (
            <ServerCard key={server.id} server={server} />
          ))}
        </VStack>
      )}
    </ScrollView>
  );
}

function ServerCard({ server }: { server: Server }) {
  const { colors, spacing } = useTheme();

  return (
    <Card variant="outline" padding="md">
      <HStack gap={3} align="center">
        <Indicator
          status={server.status === 'up' ? 'up' : server.status === 'down' ? 'down' : 'unknown'}
          size="md"
        />
        <VStack gap={0.5} flex={1}>
          <Text variant="bodyMedium">{server.name}</Text>
          <Text variant="caption" color={colors.textSubtle}>
            {server.user}@{server.host}:{server.port}
          </Text>
        </VStack>
        <VStack align="flex-end" gap={0.5}>
          <Badge color="neutral" size="sm">{server.commands.length} cmds</Badge>
          {server.latency_ms && (
            <Text variant="caption" color={colors.textMuted}>{server.latency_ms}ms</Text>
          )}
        </VStack>
      </HStack>
    </Card>
  );
}
