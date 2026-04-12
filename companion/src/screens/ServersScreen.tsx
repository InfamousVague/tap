import React, { useState } from 'react';
import { ScrollView, RefreshControl } from 'react-native';
import {
  useTheme,
  VStack,
  HStack,
  Text,
  ListItem,
  Indicator,
  Button,
  Card,
  Separator,
  Input,
  Dialog,
  icons,
  Icon,
} from '@mattssoftware/base-rn';
import { useQuery, useMutation } from '../hooks/useApi';
import { api, Server, Command } from '../services/api';

export function ServersScreen({ navigation }: any) {
  const { colors, spacing } = useTheme();
  const { data: servers, loading, refetch } = useQuery(() => api.listServers());

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[4] }}
      refreshControl={
        <RefreshControl refreshing={loading} onRefresh={refetch} tintColor={colors.accent} />
      }
    >
      <HStack justify="space-between" align="center">
        <Text variant="heading">Servers</Text>
        <Button
          variant="primary"
          size="sm"
          icon={<Icon svg={icons.plus} size={16} color="#000" />}
          onPress={() => navigation.navigate('AddServer')}
        >
          Add
        </Button>
      </HStack>

      <VStack gap={0}>
        {servers?.map((server, i) => (
          <React.Fragment key={server.id}>
            <ListItem
              title={server.name}
              subtitle={`${server.user}@${server.host} · ${server.commands.length} commands`}
              leading={
                <Indicator
                  status={server.status === 'up' ? 'up' : server.status === 'down' ? 'down' : 'unknown'}
                />
              }
              onPress={() => navigation.navigate('ServerDetail', { serverId: server.id, serverName: server.name })}
            />
            {i < (servers?.length ?? 0) - 1 && <Separator />}
          </React.Fragment>
        ))}
      </VStack>
    </ScrollView>
  );
}

export function ServerDetailScreen({ route, navigation }: any) {
  const { serverId, serverName } = route.params;
  const { colors, spacing } = useTheme();
  const { data: servers, refetch } = useQuery(() => api.listServers());
  const server = servers?.find(s => s.id === serverId);

  if (!server) return null;

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[4] }}
    >
      {/* Server info */}
      <Card variant="filled" padding="md">
        <VStack gap={2}>
          <HStack align="center" gap={2}>
            <Indicator status={server.status === 'up' ? 'up' : 'down'} size="lg" pulse />
            <Text variant="title">{server.name}</Text>
          </HStack>
          <Text variant="caption" color={colors.textSubtle} mono>
            {server.user}@{server.host}:{server.port}
          </Text>
          {server.latency_ms && (
            <Text variant="caption" color={colors.textMuted}>
              Latency: {server.latency_ms}ms
            </Text>
          )}
        </VStack>
      </Card>

      {/* Commands */}
      <HStack justify="space-between" align="center">
        <Text variant="label" color={colors.textSubtle}>Commands</Text>
        <Button
          variant="ghost"
          size="sm"
          icon={<Icon svg={icons.plus} size={16} color={colors.accent} />}
          onPress={() => navigation.navigate('AddCommand', { serverId })}
        >
          Add
        </Button>
      </HStack>

      <Card variant="outline" padding="none">
        {server.commands.map((cmd, i) => (
          <React.Fragment key={cmd.id}>
            <ListItem
              title={cmd.label}
              subtitle={cmd.command}
              trailing={cmd.pinned ? <Icon svg={icons.zap} size={14} color={colors.accent} /> : undefined}
              onPress={() => navigation.navigate('CommandDetail', { command: cmd, server })}
            />
            {i < server.commands.length - 1 && <Separator />}
          </React.Fragment>
        ))}
      </Card>

      {/* Suites */}
      {server.suites.length > 0 && (
        <>
          <Text variant="label" color={colors.textSubtle}>Suites</Text>
          <Card variant="outline" padding="none">
            {server.suites.map((suite, i) => (
              <React.Fragment key={suite.id}>
                <ListItem
                  title={suite.label}
                  leading={<Icon svg={icons.list} size={18} color={colors.textSubtle} />}
                />
                {i < server.suites.length - 1 && <Separator />}
              </React.Fragment>
            ))}
          </Card>
        </>
      )}
    </ScrollView>
  );
}
