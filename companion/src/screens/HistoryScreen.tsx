import React, { useState } from 'react';
import { ScrollView, RefreshControl } from 'react-native';
import {
  useTheme, VStack, HStack, Text, Card, Badge, Skeleton, Icon, icons,
} from '@mattssoftware/base-rn';
import { amber } from '@mattssoftware/base-rn/src/tokens/colors';
import { api, ExecHistoryEntry } from '../services/api';
import { useQuery } from '../hooks/useApi';

function relativeTime(dateStr: string | null): string {
  if (!dateStr) return '';
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = Math.floor((now - then) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function HistoryScreen() {
  const { colors, spacing } = useTheme();
  const { data: history, loading, refetch } = useQuery(() => api.listHistory(50), []);

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4] }}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={refetch} tintColor={amber[500]} />}
    >
      <VStack gap={3}>
        <Text variant="label" color={colors.textMuted}>
          {history?.length ?? 0} entries
        </Text>

        {loading && !history ? (
          <VStack gap={2}><Skeleton height={60} /><Skeleton height={60} /><Skeleton height={60} /></VStack>
        ) : history?.length === 0 ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={2}>
              <Icon svg={icons.clock} size={32} color={colors.textMuted} />
              <Text variant="body" color={colors.textMuted} align="center">No history yet</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Commands you run will appear here.
              </Text>
            </VStack>
          </Card>
        ) : (
          history?.map(entry => (
            <HistoryCard key={entry.id} entry={entry} />
          ))
        )}
      </VStack>
    </ScrollView>
  );
}

function HistoryCard({ entry }: { entry: ExecHistoryEntry }) {
  const { colors, spacing } = useTheme();
  const success = entry.exit_code === 0;
  const [expanded, setExpanded] = useState(false);
  const hasOutput = !!(entry.stdout || entry.stderr);

  return (
    <Card variant="outline" padding="md" onPress={hasOutput ? () => setExpanded(!expanded) : undefined}>
      <VStack gap={2}>
        <HStack justify="space-between" align="center">
          <HStack gap={2} align="center" style={{ flex: 1 }}>
            <Icon
              svg={success ? icons.check : icons.x}
              size={16}
              color={success ? colors.success : colors.error}
            />
            <Text variant="label" numberOfLines={1} style={{ flex: 1 }}>
              {entry.command_text ?? 'Unknown'}
            </Text>
          </HStack>
          {hasOutput && (
            <Icon
              svg={expanded ? icons.chevronUp : icons.chevronDown}
              size={14}
              color={colors.textMuted}
            />
          )}
        </HStack>

        <HStack gap={3}>
          {entry.exit_code != null && (
            <Text
              variant="caption"
              color={success ? colors.success : colors.error}
              weight="600"
              mono
            >
              exit {entry.exit_code}
            </Text>
          )}
          {entry.duration_ms != null && (
            <Text variant="caption" color={colors.textMuted} mono>{entry.duration_ms}ms</Text>
          )}
          {entry.device && (
            <Badge size="sm" color="neutral" variant="subtle">
              <Text variant="caption">{entry.device}</Text>
            </Badge>
          )}
          <Text variant="caption" color={colors.textMuted}>{relativeTime(entry.created_at)}</Text>
        </HStack>

        {expanded && hasOutput && (
          <VStack gap={1.5} style={{ marginTop: spacing[1] }}>
            {entry.stdout ? (
              <Card variant="filled" padding="sm">
                <Text variant="caption" mono color={colors.text}>
                  {entry.stdout}
                </Text>
              </Card>
            ) : null}
            {entry.stderr ? (
              <Card variant="filled" padding="sm">
                <HStack gap={1} align="center" style={{ marginBottom: spacing[1] }}>
                  <Icon svg={icons.alertTriangle} size={12} color={colors.error} />
                  <Text variant="caption" color={colors.error} weight="600">stderr</Text>
                </HStack>
                <Text variant="caption" mono color={colors.error}>
                  {entry.stderr}
                </Text>
              </Card>
            ) : null}
          </VStack>
        )}
      </VStack>
    </Card>
  );
}
