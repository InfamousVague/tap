import React from 'react';
import { ScrollView, RefreshControl } from 'react-native';
import {
  useTheme,
  VStack,
  HStack,
  Text,
  Card,
  ListItem,
  Separator,
  Badge,
  Skeleton,
  icons,
  Icon,
} from '@mattssoftware/base-rn';
import { useQuery } from '../hooks/useApi';
import { api, ExecHistoryEntry } from '../services/api';

export function HistoryScreen() {
  const { colors, spacing } = useTheme();
  const { data: history, loading, refetch } = useQuery(() => api.listHistory(50));

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[4] }}
      refreshControl={
        <RefreshControl refreshing={loading} onRefresh={refetch} tintColor={colors.accent} />
      }
    >
      <Text variant="heading">History</Text>

      {loading && !history ? (
        <VStack gap={2}>
          {[1,2,3,4,5].map(i => <Skeleton key={i} height={60} />)}
        </VStack>
      ) : history?.length === 0 ? (
        <Card variant="filled" padding="lg">
          <VStack align="center" gap={2}>
            <Icon svg={icons.clock} size={32} color={colors.textMuted} />
            <Text variant="body" color={colors.textSubtle}>No execution history yet.</Text>
          </VStack>
        </Card>
      ) : (
        <Card variant="outline" padding="none">
          {history?.map((entry, i) => (
            <React.Fragment key={entry.id}>
              <HistoryRow entry={entry} />
              {i < (history?.length ?? 0) - 1 && <Separator />}
            </React.Fragment>
          ))}
        </Card>
      )}
    </ScrollView>
  );
}

function HistoryRow({ entry }: { entry: ExecHistoryEntry }) {
  const { colors, spacing } = useTheme();
  const isSuccess = entry.exit_code === 0;
  const displayCommand = entry.command_text || 'Unknown command';

  return (
    <ListItem
      title={displayCommand}
      subtitle={formatTime(entry.created_at)}
      leading={
        <Icon
          svg={isSuccess ? icons.check : icons.x}
          size={16}
          color={isSuccess ? colors.success : colors.error}
        />
      }
      trailing={
        <HStack gap={1.5}>
          {entry.duration_ms && (
            <Badge color="neutral" size="sm">{entry.duration_ms}ms</Badge>
          )}
          {entry.device && (
            <Badge color="accent" size="sm">{entry.device}</Badge>
          )}
        </HStack>
      }
      chevron={false}
    />
  );
}

function formatTime(isoString: string | null): string {
  if (!isoString) return '';
  const date = new Date(isoString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return 'Just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDay = Math.floor(diffHr / 24);
  return `${diffDay}d ago`;
}
