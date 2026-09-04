import type { InstallationStatus } from '@oep-exchange/api-contracts';
import { createContext, useContext, useEffect, useMemo, useReducer, type ReactNode } from 'react';

/** One entry in the Downloads page's history (WP-EXC-009.md §4 "Downloads"). */
export interface DownloadRecord {
  packageId: string;
  packageDisplayName: string;
  version: string;
  downloadedAt: string;
}

/** One entry in the My Library page's history (WP-EXC-009.md §4 "My Library"). */
export interface InstallationRecord {
  installationId: string;
  packageId: string;
  packageDisplayName: string;
  version: string;
  status: InstallationStatus;
  requestedAt: string;
}

interface LibraryState {
  downloads: DownloadRecord[];
  installations: InstallationRecord[];
}

type LibraryAction =
  | { type: 'recordDownload'; record: DownloadRecord }
  | { type: 'recordInstallation'; record: InstallationRecord }
  | { type: 'updateInstallationStatus'; installationId: string; status: InstallationStatus };

/**
 * Authentication is out of scope (WP-EXC-008.md/WP-EXC-009.md §2), so
 * there is no server-side concept of "the current user's" downloads or
 * installed packages to fetch. This browser-local, `localStorage`-backed
 * history of "packages this browser downloaded/installed" is the
 * Downloads/My Library views' state — every *displayed* field (title,
 * publisher, status) still comes from a real API call keyed off the ids
 * stored here, not from fabricated data (WP-EXC-009.md §7 "The frontend
 * shall not contain mock data").
 */
const STORAGE_KEY = 'oep-exchange.publisher-portal.library.v1';

function loadInitialState(): LibraryState {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return { downloads: [], installations: [] };
    }
    const parsed = JSON.parse(raw) as Partial<LibraryState>;
    return {
      downloads: Array.isArray(parsed.downloads) ? parsed.downloads : [],
      installations: Array.isArray(parsed.installations) ? parsed.installations : [],
    };
  } catch {
    return { downloads: [], installations: [] };
  }
}

function reducer(state: LibraryState, action: LibraryAction): LibraryState {
  switch (action.type) {
    case 'recordDownload':
      return { ...state, downloads: [action.record, ...state.downloads] };
    case 'recordInstallation':
      return { ...state, installations: [action.record, ...state.installations] };
    case 'updateInstallationStatus':
      return {
        ...state,
        installations: state.installations.map((installation) =>
          installation.installationId === action.installationId
            ? { ...installation, status: action.status }
            : installation,
        ),
      };
    default:
      return state;
  }
}

export interface LibraryContextValue extends LibraryState {
  recordDownload(record: DownloadRecord): void;
  recordInstallation(record: InstallationRecord): void;
  updateInstallationStatus(installationId: string, status: InstallationStatus): void;
}

const LibraryContext = createContext<LibraryContextValue | undefined>(undefined);

export function LibraryProvider({ children }: { children: ReactNode }): JSX.Element {
  const [state, dispatch] = useReducer(reducer, undefined, loadInitialState);

  useEffect(() => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, [state]);

  const value = useMemo<LibraryContextValue>(
    () => ({
      ...state,
      recordDownload: (record) => dispatch({ type: 'recordDownload', record }),
      recordInstallation: (record) => dispatch({ type: 'recordInstallation', record }),
      updateInstallationStatus: (installationId, status) =>
        dispatch({ type: 'updateInstallationStatus', installationId, status }),
    }),
    [state],
  );

  return <LibraryContext.Provider value={value}>{children}</LibraryContext.Provider>;
}

export function useLibrary(): LibraryContextValue {
  const context = useContext(LibraryContext);
  if (!context) {
    throw new Error('useLibrary() must be called within a LibraryProvider.');
  }
  return context;
}
