import { useState, useEffect, useCallback, createContext, useContext } from 'react';
import { api } from '../services/api';

interface AuthState {
  isReady: boolean;
  isAuthenticated: boolean;
  signInWithApple: (identityToken: string, userIdentifier: string, email?: string) => Promise<void>;
  signOut: () => Promise<void>;
}

export const AuthContext = createContext<AuthState>({
  isReady: false,
  isAuthenticated: false,
  signInWithApple: async () => {},
  signOut: async () => {},
});

export function useAuth() {
  return useContext(AuthContext);
}

export function useAuthProvider(): AuthState {
  const [isReady, setIsReady] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    api.initialize().then((configured) => {
      setIsAuthenticated(configured);
      setIsReady(true);
    });
  }, []);

  const signInWithApple = useCallback(async (identityToken: string, userIdentifier: string, email?: string) => {
    await api.signInWithApple(identityToken, userIdentifier, email);
    setIsAuthenticated(true);
  }, []);

  const signOut = useCallback(async () => {
    await api.disconnect();
    setIsAuthenticated(false);
  }, []);

  return { isReady, isAuthenticated, signInWithApple, signOut };
}
