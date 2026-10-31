import type { Coords } from '../lib/maps';

/** Web / unsupported platforms: no native map. The address screen falls back to search, "use my location" and delivery-area chips. */
export const MAP_SUPPORTED = false;
export interface MapPickerProps { value: Coords | null; store: Coords | null; nearKm: number; maxKm: number; onPick: (c: Coords) => void; label: string }
export function MapPicker(_props: MapPickerProps) { return null; }
