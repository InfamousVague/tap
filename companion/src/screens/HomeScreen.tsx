import React from 'react';
import { ScrollView, RefreshControl } from 'react-native';
import {
  useTheme, VStack, HStack, Text, Card, Badge, Indicator, Skeleton, Icon, icons,
} from '@mattssoftware/base-rn';
import { amber } from '@mattssoftware/base-rn/src/tokens/colors';
import { api, Server } from '../services/api';
import { useQuery } from '../hooks/useApi';

export function HomeScreen() {
  const { colors, spacing } = useTheme();
  const { data: servers, loading, refetch } = useQuery(() => api.listServers(), []);

  const upCount = servers?.filter(s => s.status === 'up').length ?? 0;
  const downCount = servers?.filter(s => s.status === 'down').length ?? 0;
  const total = servers?.length ?? 0;

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4] }}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={refetch} tintColor={amber[500]} />}
    >
      <VStack gap={4}>
        {/* Status summary card */}
        <Card variant="filled" padding="md">
          <HStack gap={4} justify="space-around">
            <VStack align="center" gap={1}>
              <Text variant="display" color={colors.success}>{loading ? '-' : upCount}</Text>
              <Text variant="caption" color={colors.textMuted}>Online</Text>
            </VStack>
            <VStack align="center" gap={1}>
              <Text variant="display" color={downCount > 0 ? colors.error : colors.textMuted}>{loading ? '-' : downCount}</Text>
              <Text variant="caption" color={colors.textMuted}>Offline</Text>
            </VStack>
            <VStack align="center" gap={1}>
              <Text variant="display" color={amber[500]}>{loading ? '-' : total}</Text>
              <Text variant="caption" color={colors.textMuted}>Total</Text>
            </VStack>
          </HStack>
        </Card>

        <Text variant="label" color={colors.textMuted}>Servers</Text>

        {loading && !servers ? (
          <VStack gap={3}>
            <Skeleton height={80} />
            <Skeleton height={80} />
            <Skeleton height={80} />
          </VStack>
        ) : servers?.length === 0 ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={2}>
              <Icon svg={icons.server} size={32} color={colors.textMuted} />
              <Text variant="body" color={colors.textMuted} align="center">No servers yet</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Add your first server from the Servers tab.
              </Text>
            </VStack>
          </Card>
        ) : (
          <VStack gap={3}>
            {servers?.map(server => (
              <ServerCard key={server.id} server={server} />
            ))}
          </VStack>
        )}
      </VStack>
    </ScrollView>
  );
}

function ServerCard({ server }: { server: Server }) {
  const { colors } = useTheme();
  const statusType = server.status === 'up' ? 'up' as const : server.status === 'down' ? 'down' as const : 'unknown' as const;

  return (
    <Card variant="outline" padding="md">
      <VStack gap={2}>
        <HStack justify="space-between" align="center">
          <HStack gap={2} align="center">
            <Indicator status={statusType} size="sm" pulse={server.status === 'up'} />
            <Text variant="title">{server.name}</Text>
          </HStack>
          {server.latency_ms != null && (
            <Badge size="sm" color="neutral" variant="subtle">
              <Text variant="caption" mono>{server.latency_ms}ms</Text>
            </Badge>
          )}
        </HStack>

        <Text variant="caption" color={colors.textMuted} mono>
          {server.user}@{server.host}:{server.port}
        </Text>

        <HStack gap={2}>
          <Badge size="sm" color="accent" variant="subtle">
            <Text variant="caption">{server.commands.length} {server.commands.length === 1 ? 'command' : 'commands'}</Text>
          </Badge>
          {server.suites.length > 0 && (
            <Badge size="sm" color="info" variant="subtle">
              <Text variant="caption">{server.suites.length} {server.suites.length === 1 ? 'suite' : 'suites'}</Text>
            </Badge>
          )}
        </HStack>
      </VStack>
    </Card>
  );
}
