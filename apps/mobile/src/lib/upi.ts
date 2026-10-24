import { Linking, Platform } from 'react-native';

/** GET /v1/orders/:id/upi */
export interface UpiInfo {
  order_id: string; order_no: string; order_status: string; payment_status: string;
  amount: string; amount_paise: number; payable: boolean; expires_at: string | null;
  vpa: string | null; payee_name: string; merchant_mode: boolean;
  link: string | null; ios_app_links: { app: string; link: string }[];
  claimed_utr: string | null; verified: boolean;
}

export const isValidUtr = (s: string) => /^\d{12}$/.test(s.trim());

/**
 * Buttons to offer. Android shows its own chooser of installed UPI apps for one upi:// link;
 * iPhone has no chooser, so each app gets its own button (scheme-specific links built by the server).
 */
export function upiChoices(info: Pick<UpiInfo, 'link' | 'ios_app_links'>, os: string = Platform.OS): { app: string | null; link: string }[] {
  if (!info.link) return [];
  if (os === 'ios') return info.ios_app_links.map((a) => ({ app: a.app, link: a.link }));
  return [{ app: null, link: info.link }];
}

/** Opens a UPI app. `true` only means an app opened: it says nothing about payment (the store confirms that). */
export async function openUpiApp(link: string): Promise<boolean> {
  try { await Linking.openURL(link); return true; } catch { return false; }
}
