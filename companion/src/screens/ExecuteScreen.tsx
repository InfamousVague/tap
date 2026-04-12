import React, { useState } from 'react';
import { ScrollView, View } from 'react-native';
import {
  useTheme,
  VStack,
  HStack,
  Text,
  Button,
  Card,
  Progress,
  Badge,
  icons,
  Icon,
} from '@mattssoftware/base-rn';
import { api, Server, Command, ExecResult } from '../services/api';
import * as Haptics from 'expo-haptics';

interface ExecuteScreenProps {
  route: { params: { command: Command; server: Server } };
  navigation: any;
}

export function ExecuteScreen({ route, navigation }: ExecuteScreenProps) {
  const { command, server } = route.params;
  const { colors, spacing } = useTheme();
  const [status, setStatus] = useState<'idle' | 'confirming' | 'running' | 'done'>('confirming');
  const [result, setResult] = useState<ExecResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const execute = async () => {
    setStatus('running');
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    try {
      const res = await api.execute(server.id, command.id);
      setResult(res);
      setStatus('done');

      if (res.status === 'success') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      } else {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
    } catch (e: any) {
      setError(e.message);
      setStatus('done');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[6], flexGrow: 1 }}
    >
      {/* Command info */}
      <VStack gap={2} align="center">
        <Icon svg={icons.terminal} size={32} color={colors.accent} />
        <Text variant="title">{command.label}</Text>
        <Text variant="caption" color={colors.textSubtle}>on {server.name}</Text>
        <Card variant="filled" padding="sm" style={{ width: '100%', marginTop: 8 }}>
          <Text variant="caption" mono color={colors.textSubtle}>{command.command}</Text>
        </Card>
      </VStack>

      {/* States */}
      {status === 'confirming' && (
        <VStack gap={4} align="center">
          <Text variant="body" color={colors.warning}>
            {command.confirm ? 'This command requires confirmation.' : 'Ready to execute.'}
          </Text>
          <HStack gap={3}>
            <Button variant="secondary" onPress={() => navigation.goBack()}>
              Cancel
            </Button>
            <Button variant="primary" onPress={execute}>
              Run Command
            </Button>
          </HStack>
        </VStack>
      )}

      {status === 'running' && (
        <VStack gap={4} align="center">
          <Progress value={66} size="md" />
          <Text variant="body" color={colors.textSubtle}>Executing...</Text>
        </VStack>
      )}

      {status === 'done' && result && (
        <VStack gap={4}>
          {/* Result header */}
          <HStack gap={2} align="center" justify="center">
            <Icon
              svg={result.status === 'success' ? icons.check : icons.x}
              size={24}
              color={result.status === 'success' ? colors.success : colors.error}
            />
            <Text variant="title" color={result.status === 'success' ? colors.success : colors.error}>
              {result.status === 'success' ? 'Success' : 'Failed'}
            </Text>
          </HStack>

          <HStack gap={3} justify="center">
            <Badge color="neutral" size="sm">{result.duration_ms}ms</Badge>
            {result.exit_code !== null && result.exit_code !== 0 && (
              <Badge color="error" size="sm">Exit {result.exit_code}</Badge>
            )}
          </HStack>

          {/* Output */}
          {(result.stdout || result.stderr) && (
            <Card variant="filled" padding="md">
              <Text variant="caption" mono color={colors.text}>
                {result.stdout || result.stderr}
              </Text>
            </Card>
          )}

          <Button variant="secondary" onPress={() => navigation.goBack()}>
            Done
          </Button>
        </VStack>
      )}

      {status === 'done' && error && (
        <VStack gap={4} align="center">
          <Icon svg={icons.x} size={32} color={colors.error} />
          <Text variant="body" color={colors.error}>{error}</Text>
          <Button variant="secondary" onPress={() => navigation.goBack()}>
            Back
          </Button>
        </VStack>
      )}
    </ScrollView>
  );
}
