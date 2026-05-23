import React, { useState } from 'react';
import { View, Image, useColorScheme } from 'react-native';
import { useTheme, VStack, Text } from '@mattssoftware/base-rn';
import * as AppleAuthentication from 'expo-apple-authentication';
import { useAuth } from '../hooks/useAuth';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const tapLogo = require('../../assets/icon.png');

export function SignInScreen() {
  const { colors, spacing } = useTheme();
  const colorScheme = useColorScheme();
  const { signInWithApple } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleAppleSignIn = async () => {
    try {
      setLoading(true);
      setError(null);

      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [AppleAuthentication.AppleAuthenticationScope.EMAIL],
      });

      if (!credential.identityToken) {
        setError('Could not get identity token.');
        return;
      }

      await signInWithApple(credential.identityToken, credential.user, credential.email ?? undefined);
    } catch (e: any) {
      if (e.code !== 'ERR_REQUEST_CANCELED') {
        setError('Sign in failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg, justifyContent: 'center', padding: spacing[8] }}>
      <VStack gap={6} align="center">
        <Image source={tapLogo} style={{ width: 96, height: 96, borderRadius: 22 }} />
        <Text variant="display" align="center">Tap</Text>
        <Text variant="body" color={colors.textMuted} align="center">
          The command remote for your infrastructure.
        </Text>

        <View style={{ height: spacing[8] }} />

        <AppleAuthentication.AppleAuthenticationButton
          buttonType={AppleAuthentication.AppleAuthenticationButtonType.SIGN_IN}
          buttonStyle={
            colorScheme === 'dark'
              ? AppleAuthentication.AppleAuthenticationButtonStyle.WHITE
              : AppleAuthentication.AppleAuthenticationButtonStyle.BLACK
          }
          cornerRadius={12}
          style={{ width: '100%', height: 50 }}
          onPress={handleAppleSignIn}
        />

        {error && (
          <Text variant="caption" color={colors.error} align="center">{error}</Text>
        )}
      </VStack>
    </View>
  );
}
