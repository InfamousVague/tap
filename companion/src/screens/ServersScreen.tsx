import React, { useState, useEffect, useLayoutEffect } from 'react';
import { ScrollView, RefreshControl, Alert, Pressable, View } from 'react-native';
import {
  useTheme, VStack, HStack, Text, Card, Button, Input, Dialog, ListItem, Separator,
  Badge, Indicator, Icon, icons, Skeleton, useToast, Toggle,
} from '@mattssoftware/base-rn';
import { amber } from '@mattssoftware/base-rn/src/tokens/colors';
import { api, Server, Command, ExecResult } from '../services/api';
import { useQuery, useMutation } from '../hooks/useApi';
import { useNavigation } from 'expo-router';
import * as Haptics from 'expo-haptics';

export function ServersScreen() {
  const { colors, spacing } = useTheme();
  const navigation = useNavigation();
  const { data: servers, loading, error, refetch } = useQuery(() => api.listServers(), []);
  const [selectedServer, setSelectedServer] = useState<Server | null>(null);

  // Update the native header bar when a server is selected/deselected
  useLayoutEffect(() => {
    if (selectedServer) {
      navigation.setOptions({
        title: selectedServer.name,
        headerLeft: () => (
          <Pressable onPress={() => setSelectedServer(null)} style={{ paddingLeft: 16, paddingRight: 8 }}>
            <Icon svg={icons.chevronLeft} size={22} color={amber[500]} />
          </Pressable>
        ),
      });
    } else {
      navigation.setOptions({
        title: 'Servers',
        headerLeft: undefined,
      });
    }
  }, [selectedServer, navigation]);
  const [showAddServer, setShowAddServer] = useState(false);
  const [showAddCommand, setShowAddCommand] = useState(false);
  const { toast } = useToast();

  // Show toast on fetch error
  React.useEffect(() => {
    if (error) toast({ type: 'error', title: 'Failed to load servers', message: error });
  }, [error]);

  // Add server form
  const [serverName, setServerName] = useState('');
  const [serverHost, setServerHost] = useState('');
  const [serverPort, setServerPort] = useState('22');
  const [serverUser, setServerUser] = useState('root');

  // Add command form
  const [cmdLabel, setCmdLabel] = useState('');
  const [cmdCommand, setCmdCommand] = useState('');
  const [cmdConfirm, setCmdConfirm] = useState(false);

  const addServer = useMutation(async () => {
    try {
      await api.createServer({ name: serverName, host: serverHost, port: parseInt(serverPort), user: serverUser });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      toast({ type: 'success', title: `Server "${serverName}" added` });
      setShowAddServer(false);
      setServerName(''); setServerHost(''); setServerPort('22'); setServerUser('root');
      refetch();
    } catch (e: any) {
      toast({ type: 'error', title: 'Failed to add server', message: e.message });
      throw e;
    }
  });

  const addCommand = useMutation(async () => {
    if (!selectedServer) return;
    try {
      await api.createCommand(selectedServer.id, { label: cmdLabel, command: cmdCommand, confirm: cmdConfirm });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      toast({ type: 'success', title: `Command "${cmdLabel}" added` });
      setShowAddCommand(false);
      setCmdLabel(''); setCmdCommand(''); setCmdConfirm(false);
      refetch();
    } catch (e: any) {
      toast({ type: 'error', title: 'Failed to add command', message: e.message });
      throw e;
    }
  });

  const deleteServer = (server: Server) => {
    Alert.alert('Delete Server', `Remove "${server.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete', style: 'destructive', onPress: async () => {
          try {
            await api.deleteServer(server.id);
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            toast({ type: 'success', title: `Server "${server.name}" deleted` });
            if (selectedServer?.id === server.id) setSelectedServer(null);
            refetch();
          } catch (e: any) {
            toast({ type: 'error', title: 'Failed to delete server', message: e.message });
          }
        }
      },
    ]);
  };

  const importSshConfig = async () => {
    try {
      const result = await api.importSshConfig();
      toast({ type: 'success', title: `Imported ${result.imported} servers` });
      refetch();
    } catch {
      toast({ type: 'error', title: 'Import failed' });
    }
  };

  if (selectedServer) {
    const server = servers?.find(s => s.id === selectedServer.id) ?? selectedServer;
    return (
      <ServerDetailScreen
        server={server}
        onBack={() => setSelectedServer(null)}
        onAddCommand={() => setShowAddCommand(true)}
        onRefetch={refetch}
        showAddCommand={showAddCommand}
        setShowAddCommand={setShowAddCommand}
        cmdLabel={cmdLabel}
        setCmdLabel={setCmdLabel}
        cmdCommand={cmdCommand}
        setCmdCommand={setCmdCommand}
        cmdConfirm={cmdConfirm}
        setCmdConfirm={setCmdConfirm}
        addCommand={addCommand}
      />
    );
  }

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4] }}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={refetch} tintColor={amber[500]} />}
    >
      <VStack gap={4}>
        <HStack justify="space-between" align="center">
          <Text variant="label" color={colors.textMuted}>
            {servers?.length ?? 0} servers
          </Text>
          <HStack gap={2}>
            <Button variant="secondary" size="sm" style={{ backgroundColor: colors.bgMuted, borderWidth: 0 }} onPress={importSshConfig}
              icon={<Icon svg={icons.download} size={14} color={colors.textMuted} />}
            >
              Import SSH
            </Button>
            <Button variant="primary" size="sm" onPress={() => setShowAddServer(true)}
              icon={<Icon svg={icons.plus} size={14} color="white" />}
            >
              Add
            </Button>
          </HStack>
        </HStack>

        {loading && !servers ? (
          <VStack gap={2}><Skeleton height={72} /><Skeleton height={72} /><Skeleton height={72} /></VStack>
        ) : error && !servers ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={2}>
              <Icon svg={icons.alertTriangle} size={32} color={colors.error} />
              <Text variant="body" color={colors.error} align="center">Failed to load servers</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Pull down to retry.
              </Text>
            </VStack>
          </Card>
        ) : servers?.length === 0 ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={3}>
              <Icon svg={icons.server} size={40} color={colors.textMuted} />
              <Text variant="body" color={colors.textMuted} align="center">No servers yet</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Add a server or import from your SSH config.
              </Text>
            </VStack>
          </Card>
        ) : (
          <VStack gap={2}>
            {servers?.map(server => (
              <Card key={server.id} variant="outline" padding="md" onPress={() => setSelectedServer(server)}>
                <HStack justify="space-between" align="center">
                  <HStack gap={3} align="center" style={{ flex: 1 }}>
                    <Indicator status={server.status === 'up' ? 'up' : server.status === 'down' ? 'down' : 'unknown'} size="sm" pulse={server.status === 'up'} />
                    <VStack gap={0.5} style={{ flex: 1 }}>
                      <Text variant="title">{server.name}</Text>
                      <Text variant="caption" color={colors.textMuted} mono numberOfLines={1}>
                        {server.user}@{server.host}
                      </Text>
                    </VStack>
                  </HStack>
                  <HStack gap={2} align="center">
                    <Badge size="sm" style={{ backgroundColor: '#2a2a2e', borderRadius: 6 }}>
                      <Text variant="caption" color="#e4e4e7">{server.commands.length} cmds</Text>
                    </Badge>
                    <Icon svg={icons.chevronRight} size={16} color={colors.textMuted} />
                  </HStack>
                </HStack>
              </Card>
            ))}
          </VStack>
        )}
      </VStack>

      {/* Add Server Dialog */}
      <Dialog visible={showAddServer} onClose={() => setShowAddServer(false)} title="Add Server">
        <VStack gap={3}>
          <Input label="Name" placeholder="prod-api" value={serverName} onChangeText={setServerName} />
          <Input label="Host" placeholder="10.0.1.10" value={serverHost} onChangeText={setServerHost} />
          <HStack gap={3}>
            <View style={{ flex: 1 }}>
              <Input label="Port" placeholder="22" value={serverPort} onChangeText={setServerPort} keyboardType="number-pad" />
            </View>
            <View style={{ flex: 1 }}>
              <Input label="User" placeholder="root" value={serverUser} onChangeText={setServerUser} />
            </View>
          </HStack>
          <Button variant="primary" onPress={() => addServer.execute()} loading={addServer.loading} disabled={!serverName || !serverHost}>
            <Text variant="label" color="white">Add Server</Text>
          </Button>
        </VStack>
      </Dialog>
    </ScrollView>
  );
}

function ServerDetailScreen({
  server, onBack, onAddCommand, onRefetch, showAddCommand, setShowAddCommand,
  cmdLabel, setCmdLabel, cmdCommand, setCmdCommand, cmdConfirm, setCmdConfirm, addCommand,
}: {
  server: Server;
  onBack: () => void;
  onAddCommand: () => void;
  onRefetch: () => void;
  showAddCommand: boolean;
  setShowAddCommand: (v: boolean) => void;
  cmdLabel: string;
  setCmdLabel: (v: string) => void;
  cmdCommand: string;
  setCmdCommand: (v: string) => void;
  cmdConfirm: boolean;
  setCmdConfirm: (v: boolean) => void;
  addCommand: { execute: () => void; loading: boolean };
}) {
  const { colors, spacing } = useTheme();
  const statusType = server.status === 'up' ? 'up' as const : server.status === 'down' ? 'down' as const : 'unknown' as const;
  const { toast } = useToast();
  const [execResult, setExecResult] = useState<{ cmd: Command; result: ExecResult } | null>(null);
  const [executing, setExecuting] = useState<string | null>(null);

  const deleteCommand = (cmd: Command) => {
    Alert.alert('Delete Command', `Remove "${cmd.label}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete', style: 'destructive', onPress: async () => {
          try {
            await api.deleteCommand(cmd.id);
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            toast({ type: 'success', title: `Command "${cmd.label}" deleted` });
            onRefetch();
          } catch (e: any) {
            toast({ type: 'error', title: 'Failed to delete command', message: e.message });
          }
        }
      },
    ]);
  };

  const executeCommand = async (cmd: Command) => {
    if (cmd.confirm) {
      Alert.alert('Confirm Execution', `Run "${cmd.label}" on ${server.name}?`, [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Run', style: 'destructive', onPress: () => doExecute(cmd) },
      ]);
    } else {
      doExecute(cmd);
    }
  };

  const doExecute = async (cmd: Command) => {
    try {
      setExecuting(cmd.id);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      const result = await api.execute(server.id, cmd.id);
      setExecResult({ cmd, result });
      if (result.status === 'success') {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      } else {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      }
    } catch {
      toast({ type: 'error', title: `Failed to execute ${cmd.label}` });
    } finally {
      setExecuting(null);
    }
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ paddingHorizontal: spacing[4], paddingBottom: spacing[4] }}
    >
      <VStack gap={4} style={{ paddingTop: spacing[2] }}>
        {/* Black server info card */}
        <Card style={{ backgroundColor: '#000', borderRadius: 16, overflow: 'hidden' }} padding="md">
          <VStack gap={2}>
            <HStack align="center" gap={2}>
              <Indicator status={statusType} size="md" pulse={server.status === 'up'} />
              <Text variant="heading" color="#fff" style={{ flex: 1 }}>{server.name}</Text>
            </HStack>
            <Text variant="caption" color="#a1a1aa" mono>
              {server.user}@{server.host}:{server.port}
            </Text>
            <HStack gap={2}>
              {server.latency_ms != null && (
                <Badge size="sm" style={{ backgroundColor: '#1a1a1e', borderRadius: 6 }}>
                  <Text variant="caption" color="#4ade80" mono>{server.latency_ms}ms</Text>
                </Badge>
              )}
              <Badge size="sm" style={{ backgroundColor: '#1a1a1e', borderRadius: 6 }}>
                <Text variant="caption" color="#a1a1aa">{server.commands.length} commands</Text>
              </Badge>
            </HStack>
          </VStack>
        </Card>

        {/* Execution result */}
        {execResult && (
          <Card variant={execResult.result.status === 'success' ? 'outline' : 'outline'} padding="md">
            <VStack gap={2}>
              <HStack justify="space-between" align="center">
                <HStack gap={2} align="center">
                  <Icon
                    svg={execResult.result.status === 'success' ? icons.check : icons.x}
                    size={16}
                    color={execResult.result.status === 'success' ? colors.success : colors.error}
                  />
                  <Text variant="label">{execResult.cmd.label}</Text>
                </HStack>
                <HStack gap={2} align="center">
                  <Text
                    variant="caption"
                    color={execResult.result.exit_code === 0 ? colors.success : colors.error}
                    weight="600"
                  >
                    exit {execResult.result.exit_code ?? '?'}
                  </Text>
                  <Text variant="caption" color={colors.textMuted} mono>
                    {execResult.result.duration_ms}ms
                  </Text>
                  <Button variant="ghost" size="sm" onPress={() => setExecResult(null)}>
                    <Icon svg={icons.x} size={14} color={colors.textMuted} />
                  </Button>
                </HStack>
              </HStack>

              {execResult.result.stdout ? (
                <Card variant="filled" padding="sm">
                  <Text variant="caption" mono color={colors.text} numberOfLines={12}>
                    {execResult.result.stdout}
                  </Text>
                </Card>
              ) : null}

              {execResult.result.stderr ? (
                <Card variant="filled" padding="sm">
                  <Text variant="caption" mono color={colors.error} numberOfLines={8}>
                    {execResult.result.stderr}
                  </Text>
                </Card>
              ) : null}
            </VStack>
          </Card>
        )}

        {/* Commands section */}
        <HStack justify="space-between" align="center">
          <Text variant="label" color={colors.textMuted}>Commands</Text>
          <Button variant="secondary" size="sm" style={{ backgroundColor: colors.bgMuted, borderWidth: 0 }} onPress={onAddCommand}
            icon={<Icon svg={icons.plus} size={12} color={colors.textMuted} />}
          >
            Add
          </Button>
        </HStack>

        {server.commands.length === 0 ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={2}>
              <Icon svg={icons.terminal} size={32} color={colors.textMuted} />
              <Text variant="body" color={colors.textMuted} align="center">No commands yet</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Add commands to run on this server.
              </Text>
            </VStack>
          </Card>
        ) : (
          <VStack gap={2}>
            {server.commands
              .sort((a, b) => a.sort_order - b.sort_order)
              .map(cmd => (
                <Card key={cmd.id} variant="outline" padding="md">
                  <HStack justify="space-between" align="center">
                    <VStack gap={1} style={{ flex: 1 }}>
                      <HStack gap={2} align="center">
                        <Text variant="title">{cmd.label}</Text>
                        {cmd.pinned && (
                          <Icon svg={icons.zap} size={12} color={amber[500]} />
                        )}
                        {cmd.confirm && (
                          <Badge size="sm" color="warning" variant="subtle">
                            <Text variant="caption">confirm</Text>
                          </Badge>
                        )}
                      </HStack>
                      <Text variant="caption" color={colors.textMuted} mono numberOfLines={1}>
                        {cmd.command}
                      </Text>
                    </VStack>
                    <HStack gap={2}>
                      <Button
                        variant="primary"
                        size="sm"
                        onPress={() => executeCommand(cmd)}
                        loading={executing === cmd.id}
                        icon={<Icon svg={icons.play} size={12} color="#fff" />}
                      >
                        Run
                      </Button>
                      <Button
                        variant="secondary"
                        intent="error"
                        size="sm"
                        style={{ borderWidth: 0 }}
                        onPress={() => deleteCommand(cmd)}
                        icon={<Icon svg={icons.trash} size={12} color={colors.error} />}
                        iconOnly
                      />
                    </HStack>
                  </HStack>
                </Card>
              ))}
          </VStack>
        )}

        {/* Suites section */}
        {server.suites.length > 0 && (
          <>
            <Text variant="label" color={colors.textMuted}>Suites</Text>
            <Card variant="outline" padding="none">
              {server.suites.map((suite, i) => (
                <React.Fragment key={suite.id}>
                  {i > 0 && <Separator />}
                  <ListItem
                    title={suite.label}
                    leading={<Icon svg={icons.list} size={18} color={amber[500]} />}
                  />
                </React.Fragment>
              ))}
            </Card>
          </>
        )}
      </VStack>

      {/* Add Command Dialog */}
      <Dialog visible={showAddCommand} onClose={() => setShowAddCommand(false)} title="Add Command">
        <VStack gap={3}>
          <Input label="Label" placeholder="Restart API" value={cmdLabel} onChangeText={setCmdLabel} />
          <Input label="Command" placeholder="systemctl restart api" value={cmdCommand} onChangeText={setCmdCommand} />
          <HStack justify="space-between" align="center">
            <VStack gap={0.5}>
              <Text variant="label">Require confirmation</Text>
              <Text variant="caption" color={colors.textMuted}>Prompt before running</Text>
            </VStack>
            <Toggle value={cmdConfirm} onValueChange={setCmdConfirm} />
          </HStack>
          <Button variant="primary" onPress={() => addCommand.execute()} loading={addCommand.loading} disabled={!cmdLabel || !cmdCommand}>
            <Text variant="label" color="white">Add Command</Text>
          </Button>
        </VStack>
      </Dialog>
    </ScrollView>
  );
}

export { ServerDetailScreen };
