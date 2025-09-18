export interface FlatTxn {
  category: string;
  brand: string;
  brand_raw: string;
  product: string;
  qty: number;
  unit: string;
  unit_price: number;
  total_price: number;
  device: string;
  store: number;
  storename: string;
  storelocationmaster: string;
  storedeviceid: string | null;
  storedevicename: string | null;
  location: string;
  transaction_id: string;

  date_ph: string;
  time_ph: string;
  day_of_week: string;
  weekday_weekend: string;
  time_of_day: string;
  payment_method: string | null;
  bought_with_other_brands: string | null;
  transcript_audio: string | null;
  edge_version: string | null;
  sku: string | null;
  ts_ph: string;

  facialid: string | null;
  gender: string | null;
  emotion: string | null;
  age: number | null;
  agebracket: string | null;
  storeid: number;
  interactionid: string | null;
  productid: string | null;
  transactiondate: string;
  deviceid: string;
  sex: string | null;
  age__query_4_1: number | null;
  emotionalstate: string | null;
  transcriptiontext: string | null;
  gender__query_4_1: string | null;
  barangay: string | null;
  storename__query_10: string | null;
  location__query_10: string | null;
  size: number | null;
  geolatitude: number | null;
  geolongitude: number | null;
  storegeometry: string | null;
  managername: string | null;
  managercontactinfo: string | null;
  devicename: string | null;
  deviceid__query_10: string | null;
  barangay__query_10: string | null;
}

export interface Paged<T> {
  rows: T[];
  total: number;
  page: number;
  pageSize: number;
}