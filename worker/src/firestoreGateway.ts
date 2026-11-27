import { getGoogleAccessToken } from "./firebaseAuth";

/**
 * Minimal Admin-SDK-shaped Firestore read gateway for callable migrations.
 *
 * The existing domain modules were written against `firebase-admin`'s `db`
 * object. Reusing them verbatim keeps the Flutter response contract identical;
 * this adapter supplies only the read surface those modules touch.
 */

const DATASTORE_SCOPE = "https://www.googleapis.com/auth/datastore";
const DOCUMENTS_MARKER = "/documents/";

export interface FirestoreGatewayEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}

type FirestoreValue = Record<string, unknown>;
type FirestoreDocument = {
  name?: string;
  fields?: Record<string, FirestoreValue>;
};

export type GatewayOptions = {
  token?: string;
  fetcher?: typeof fetch;
};

/** Firestore sentinel values used by the existing Admin-SDK domain modules. */
export class FieldValueSentinel {
  constructor(
    readonly op: "serverTimestamp" | "delete" | "increment",
    readonly operand?: number,
  ) {}
}

export const FieldValue = {
  serverTimestamp: () => new FieldValueSentinel("serverTimestamp"),
  delete: () => new FieldValueSentinel("delete"),
  increment: (operand: number) => new FieldValueSentinel("increment", operand),
};

type FieldTransform = {
  fieldPath: string;
  setToServerValue?: "REQUEST_TIME";
  increment?: { operand: FirestoreValue };
};

type WriteOperation = {
  update?: {
    name: string;
    fields: Record<string, FirestoreValue>;
    updateMask?: { fieldPaths: string[] };
    fieldTransforms?: FieldTransform[];
  };
  delete?: string;
  currentDocument?: { exists?: boolean };
};

export class FirestoreWriteError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = "FirestoreWriteError";
  }
}

export class RestTimestamp {
  constructor(private readonly iso: string) {}

  toDate(): Date {
    return new Date(this.iso);
  }

  toMillis(): number {
    return new Date(this.iso).getTime();
  }

  valueOf(): number {
    return this.toMillis();
  }

  toJSON(): string {
    return this.iso;
  }
}

export function decodeFirestoreValue(value: FirestoreValue | undefined): unknown {
  if (!value || typeof value !== "object") return null;
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return new RestTimestamp(String(value.timestampValue));
  if ("bytesValue" in value) return value.bytesValue;
  if ("referenceValue" in value) return value.referenceValue;
  if ("geoPointValue" in value) return value.geoPointValue;
  if ("arrayValue" in value) {
    const array = value.arrayValue as { values?: FirestoreValue[] };
    return (array.values ?? []).map((item) => decodeFirestoreValue(item));
  }
  if ("mapValue" in value) {
    const map = value.mapValue as { fields?: Record<string, FirestoreValue> };
    return decodeFirestoreFields(map.fields ?? {});
  }
  return null;
}

export function decodeFirestoreFields(
  fields: Record<string, FirestoreValue>,
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    out[key] = decodeFirestoreValue(value);
  }
  return out;
}

export function encodeFirestoreValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date || (value as { toDate?: unknown })?.toDate) {
    const date = value instanceof Date
      ? value
      : (value as { toDate: () => Date }).toDate();
    return { timestampValue: date.toISOString() };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map((item) => encodeFirestoreValue(item)) } };
  }
  if (typeof value === "object") {
    const fields: Record<string, FirestoreValue> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      fields[key] = encodeFirestoreValue(item);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

export function documentPathFromName(name: string): string {
  const index = name.indexOf(DOCUMENTS_MARKER);
  const path = index >= 0 ? name.slice(index + DOCUMENTS_MARKER.length) : name;
  return path.split("/").map((segment) => decodeURIComponent(segment)).join("/");
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null &&
    !Array.isArray(value) && !(value instanceof Date) &&
    !(typeof (value as { toDate?: unknown }).toDate === "function") &&
    !(value instanceof FieldValueSentinel);
}

function joinPath(prefix: string, segment: string): string {
  return prefix ? `${prefix}.${segment}` : segment;
}

/** Field paths that an Admin-style `set`/`update` payload touches. */
export function writeFieldPaths(value: unknown, prefix = ""): string[] {
  if (!isPlainObject(value)) return [prefix];
  const entries = Object.entries(value);
  if (entries.length === 0) return [prefix];
  return entries.flatMap(([key, item]) =>
    writeFieldPaths(item, joinPath(prefix, key)),
  );
}

/** Field paths already present in a Firestore document (for replace semantics). */
function existingFieldPaths(
  fields: Record<string, FirestoreValue> | undefined,
  prefix = "",
): string[] {
  if (!fields) return [];
  return Object.entries(fields).flatMap(([key, value]) => {
    const path = joinPath(prefix, key);
    const map = value.mapValue as { fields?: Record<string, FirestoreValue> } | undefined;
    return map?.fields && Object.keys(map.fields).length > 0
      ? existingFieldPaths(map.fields, path)
      : [path];
  });
}

function setAtPath(
  fields: Record<string, FirestoreValue>,
  segments: string[],
  value: FirestoreValue,
): void {
  let cursor = fields;
  for (const segment of segments.slice(0, -1)) {
    const existing = cursor[segment];
    const nested = (existing?.mapValue as { fields?: Record<string, FirestoreValue> } | undefined)
      ?.fields ?? {};
    const next: FirestoreValue = { mapValue: { fields: nested } };
    cursor[segment] = next;
    cursor = nested;
  }
  cursor[segments[segments.length - 1] ?? ""] = value;
}

type BuildWriteOptions = {
  resourceName: string;
  data?: Record<string, unknown>;
  mask?: string[];
  transforms?: FieldTransform[];
  currentDocument?: { exists?: boolean };
};

function buildUpdateWrite({
  resourceName,
  data = {},
  mask = [],
  transforms = [],
  currentDocument,
}: BuildWriteOptions): WriteOperation {
  const fields: Record<string, FirestoreValue> = {};
  const paths = new Set(mask);
  const fieldTransforms: FieldTransform[] = [...transforms];
  for (const [key, value] of Object.entries(data)) {
    if (value instanceof FieldValueSentinel) {
      paths.add(key);
      if (value.op === "serverTimestamp") {
        fieldTransforms.push({ fieldPath: key, setToServerValue: "REQUEST_TIME" });
      } else if (value.op === "increment") {
        fieldTransforms.push({
          fieldPath: key,
          increment: { operand: encodeFirestoreValue(value.operand ?? 0) },
        });
      }
      continue;
    }
    // Admin SDK interprets dots in update keys as nested field paths.
    setAtPath(fields, key.split("."), encodeFirestoreValue(value));
    for (const path of writeFieldPaths(value, key)) paths.add(path);
  }
  const update: WriteOperation["update"] = { name: resourceName, fields };
  const fieldPaths = [...paths];
  if (fieldPaths.length > 0) update.updateMask = { fieldPaths };
  if (fieldTransforms.length > 0) update.fieldTransforms = fieldTransforms;
  return { update, ...(currentDocument ? { currentDocument } : {}) };
}

function buildWriteFromData(
  resourceName: string,
  data: Record<string, unknown>,
  options: { merge?: boolean; existingFields?: Record<string, FirestoreValue> } = {},
): WriteOperation {
  const paths = options.merge ? [] : existingFieldPaths(options.existingFields);
  return buildUpdateWrite({ resourceName, data, mask: paths });
}

const FILTER_OPERATORS: Record<string, string> = {
  "==": "EQUAL",
  "!=": "NOT_EQUAL",
  ">": "GREATER_THAN",
  ">=": "GREATER_THAN_OR_EQUAL",
  "<": "LESS_THAN",
  "<=": "LESS_THAN_OR_EQUAL",
  in: "IN",
  "array-contains": "ARRAY_CONTAINS",
  "array-contains-any": "ARRAY_CONTAINS_ANY",
};

type QueryFilter = { field: string; operator: string; value: unknown };
type QueryOrder = { field: string; direction: "ASCENDING" | "DESCENDING" };
type QuerySource = { collectionId: string; allDescendants: boolean };

class DocumentSnapshot {
  constructor(
    private readonly rest: FirestoreRest,
    readonly id: string,
    readonly refPath: string,
    private readonly document: FirestoreDocument | null,
  ) {}

  get exists(): boolean {
    return this.document != null;
  }

  get ref(): { path: string; id: string } {
    return { path: this.refPath, id: this.id };
  }

  data(): Record<string, unknown> | undefined {
    return this.document?.fields
      ? decodeFirestoreFields(this.document.fields)
      : undefined;
  }
}

class DocumentReference {
  constructor(private readonly rest: FirestoreRest, readonly path: string) {}

  get id(): string {
    return this.path.split("/").pop() ?? "";
  }

  collection(path: string): CollectionReference {
    return new CollectionReference(this.rest, `${this.path}/${path}`);
  }

  async get(): Promise<DocumentSnapshot> {
    return this.rest.getDocument(this.path);
  }

  async set(
    data: Record<string, unknown>,
    options: { merge?: boolean } = {},
  ): Promise<void> {
    const existing = options.merge === true
      ? undefined
      : (await this.rest.getDocument(this.path)).data();
    const write = buildWriteFromData(
      this.rest.resourceName(this.path),
      data,
      { merge: options.merge === true, existingFields: encodeFields(existing) },
    );
    await this.rest.commit([write]);
  }

  async update(data: Record<string, unknown>): Promise<void> {
    await this.rest.commit([buildUpdateWrite({
      resourceName: this.rest.resourceName(this.path),
      data,
      currentDocument: { exists: true },
    })]);
  }

  async create(data: Record<string, unknown>): Promise<void> {
    await this.rest.commit([buildUpdateWrite({
      resourceName: this.rest.resourceName(this.path),
      data,
      currentDocument: { exists: false },
    })]);
  }

  async delete(): Promise<void> {
    await this.rest.commit([{ delete: this.rest.resourceName(this.path) }]);
  }
}

function encodeFields(data: Record<string, unknown> | undefined): Record<string, FirestoreValue> | undefined {
  if (!data) return undefined;
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeFirestoreValue(value)]),
  );
}

class QueryBuilder {
  protected filters: QueryFilter[] = [];
  protected orders: QueryOrder[] = [];
  protected rowLimit?: number;

  constructor(
    protected readonly rest: FirestoreRest,
    protected readonly source: QuerySource,
    protected readonly collectionPath?: string,
    protected readonly parentPath?: string,
  ) {}

  where(field: string, operator: string, value: unknown): this {
    if (!FILTER_OPERATORS[operator]) {
      throw new Error(`Unsupported Firestore operator: ${operator}`);
    }
    this.filters.push({ field, operator, value });
    return this;
  }

  orderBy(field: string, direction: "asc" | "desc" = "asc"): this {
    this.orders.push({
      field,
      direction: direction === "desc" ? "DESCENDING" : "ASCENDING",
    });
    return this;
  }

  limit(value: number): this {
    this.rowLimit = value;
    return this;
  }

  async get(transaction?: string): Promise<{ docs: DocumentSnapshot[] }> {
    const structuredQuery: Record<string, unknown> = {
      from: [
        this.source.allDescendants
          ? { collectionId: this.source.collectionId, allDescendants: true }
          : { collectionId: this.source.collectionId },
      ],
    };
    if (this.filters.length === 1) {
      structuredQuery.where = { fieldFilter: this.fieldFilter(this.filters[0]) };
    } else if (this.filters.length > 1) {
      structuredQuery.where = {
        compositeFilter: {
          op: "AND",
          filters: this.filters.map((filter) => ({ fieldFilter: this.fieldFilter(filter) })),
        },
      };
    }
    if (this.orders.length > 0) {
      structuredQuery.orderBy = this.orders.map((order) => ({
        field: { fieldPath: order.field },
        direction: order.direction,
      }));
    }
    if (this.rowLimit != null) structuredQuery.limit = this.rowLimit;

    const rows = await this.rest.runQuery(
      structuredQuery,
      this.source.allDescendants ? undefined : this.parentPath,
      transaction,
    );
    return {
      docs: rows
        .filter((row) => row.document)
        .map((row) => {
          const document = row.document as FirestoreDocument;
          const path = documentPathFromName(document.name ?? "");
          return new DocumentSnapshot(
            this.rest,
            path.split("/").pop() ?? "",
            path,
            document,
          );
        }),
    };
  }

  private fieldFilter(filter: QueryFilter): Record<string, unknown> {
    return {
      field: { fieldPath: filter.field },
      op: FILTER_OPERATORS[filter.operator],
      value: encodeFirestoreValue(filter.value),
    };
  }
}

class CollectionReference extends QueryBuilder {
  constructor(rest: FirestoreRest, path: string) {
    const segments = path.split("/");
    const parentPath = segments.slice(0, -1).join("/");
    super(
      rest,
      { collectionId: segments[segments.length - 1] ?? "", allDescendants: false },
      path,
      parentPath || undefined,
    );
  }

  doc(id?: string): DocumentReference {
    // Admin SDK's doc() without an argument generates a random document ID.
    const documentId = id ?? (globalThis.crypto?.randomUUID
      ? globalThis.crypto.randomUUID()
      : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`);
    return new DocumentReference(this.rest, `${this.collectionPath}/${documentId}`);
  }
}

class CollectionGroupReference extends QueryBuilder {
  constructor(rest: FirestoreRest, collectionId: string) {
    super(rest, { collectionId, allDescendants: true });
  }
}

class FirestoreRest {
  private readonly base: string;
  private readonly callFetch: typeof fetch;

  constructor(
    private readonly projectId: string,
    private readonly token: string,
    fetcher?: typeof fetch,
  ) {
    // Workers' global fetch rejects an incorrect `this`; never call a stored
    // reference as a method of this gateway.
    this.callFetch = fetcher
      ? (input, init) => fetcher(input, init)
      : (input, init) => globalThis.fetch(input, init);
    this.base =
      `https://firestore.googleapis.com/v1/projects/${projectId}` +
      `/databases/(default)/documents`;
  }

  private headers(): Record<string, string> {
    return { Authorization: `Bearer ${this.token}` };
  }

  private encodePath(path: string): string {
    return path.split("/").map((segment) => encodeURIComponent(segment)).join("/");
  }

  resourceName(path: string): string {
    return `projects/${this.projectId}/databases/(default)/documents/${path}`;
  }

  async getDocument(path: string, transaction?: string): Promise<DocumentSnapshot> {
    const transactionQuery = transaction
      ? `?transaction=${encodeURIComponent(transaction)}`
      : "";
    const response = await this.callFetch(
      `${this.base}/${this.encodePath(path)}${transactionQuery}`,
      { headers: this.headers() },
    );
    if (response.status === 404) {
      return new DocumentSnapshot(this, path.split("/").pop() ?? "", path, null);
    }
    if (!response.ok) throw new FirestoreWriteError(
      response.status,
      `Firestore read failed (${response.status}).`,
    );
    const document = await response.json() as FirestoreDocument;
    return new DocumentSnapshot(
      this,
      path.split("/").pop() ?? "",
      path,
      document,
    );
  }

  async runQuery(
    structuredQuery: Record<string, unknown>,
    parentPath?: string,
    transaction?: string,
  ): Promise<Array<{ document?: FirestoreDocument }>> {
    const target = parentPath
      ? `${this.base}/${this.encodePath(parentPath)}:runQuery`
      : `${this.base}:runQuery`;
    const response = await this.callFetch(target, {
      method: "POST",
      headers: { ...this.headers(), "content-type": "application/json" },
      // `transaction` is the RunQuery consistency selector; it must be in the
      // body, not a query parameter, for reads inside an active transaction.
      body: JSON.stringify({ structuredQuery, ...(transaction ? { transaction } : {}) }),
    });
    if (!response.ok) throw new Error(`Firestore query failed (${response.status}).`);
    return await response.json() as Array<{ document?: FirestoreDocument }>;
  }

  async beginTransaction(): Promise<string> {
    const response = await this.callFetch(`${this.base}:beginTransaction`, {
      method: "POST",
      headers: { ...this.headers(), "content-type": "application/json" },
      body: JSON.stringify({ options: { readWrite: {} } }),
    });
    if (!response.ok) throw new FirestoreWriteError(
      response.status,
      `Firestore transaction could not start (${response.status}).`,
    );
    const body = await response.json() as { transaction?: string };
    if (!body.transaction) throw new Error("Firestore transaction id is missing.");
    return body.transaction;
  }

  async commit(writes: WriteOperation[], transaction?: string): Promise<void> {
    if (writes.length === 0) return;
    const response = await this.callFetch(`${this.base}:commit`, {
      method: "POST",
      headers: { ...this.headers(), "content-type": "application/json" },
      body: JSON.stringify({
        writes,
        ...(transaction ? { transaction } : {}),
      }),
    });
    if (!response.ok) throw new FirestoreWriteError(
      response.status,
      `Firestore write failed (${response.status}).`,
    );
  }

  async rollback(transaction: string): Promise<void> {
    try {
      await this.callFetch(`${this.base}:rollback`, {
        method: "POST",
        headers: { ...this.headers(), "content-type": "application/json" },
        body: JSON.stringify({ transaction }),
      });
    } catch { /* best-effort cleanup; the transaction is already abandoned */ }
  }

  async runTransaction<T>(callback: (transaction: RestTransaction) => Promise<T>): Promise<T> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const id = await this.beginTransaction();
      const writes: WriteOperation[] = [];
      const transaction = new RestTransaction(this, id, writes);
      try {
        const result = await callback(transaction);
        if (writes.length > 0) await this.commit(writes, id);
        else await this.rollback(id);
        return result;
      } catch (error) {
        lastError = error;
        await this.rollback(id);
        // A transaction can be aborted by concurrent writers. Retrying is
        // safe because domain callbacks only queue writes and perform their
        // external side effects after runTransaction resolves.
        if (error instanceof FirestoreWriteError && error.status === 409) continue;
        throw error;
      }
    }
    throw lastError;
  }

  collection(path: string): CollectionReference {
    return new CollectionReference(this, path);
  }

  collectionGroup(collectionId: string): CollectionGroupReference {
    return new CollectionGroupReference(this, collectionId);
  }

  batch(): WriteBatch {
    return new WriteBatch(this);
  }
}

/** Admin-SDK-shaped `db.batch()` for domain helpers outside a transaction. */
export class WriteBatch {
  private readonly writes: WriteOperation[] = [];

  constructor(private readonly rest: FirestoreRest) {}

  set(
    ref: DocumentReference,
    data: Record<string, unknown>,
    options: { merge?: boolean } = {},
  ): this {
    this.writes.push(buildWriteFromData(
      this.rest.resourceName(ref.path),
      data,
      { merge: options.merge === true },
    ));
    return this;
  }

  update(ref: DocumentReference, data: Record<string, unknown>): this {
    this.writes.push(buildUpdateWrite({
      resourceName: this.rest.resourceName(ref.path),
      data,
      currentDocument: { exists: true },
    }));
    return this;
  }

  create(ref: DocumentReference, data: Record<string, unknown>): this {
    this.writes.push(buildUpdateWrite({
      resourceName: this.rest.resourceName(ref.path),
      data,
      currentDocument: { exists: false },
    }));
    return this;
  }

  delete(ref: DocumentReference): this {
    this.writes.push({ delete: this.rest.resourceName(ref.path) });
    return this;
  }

  async commit(): Promise<void> {
    await this.rest.commit(this.writes);
  }
}

/** Admin-SDK-shaped write surface exposed inside `db.runTransaction`. */
export class RestTransaction {
  constructor(
    private readonly rest: FirestoreRest,
    private readonly transactionId: string,
    private readonly writes: WriteOperation[],
  ) {}

  get(ref: DocumentReference | QueryBuilder): Promise<any> {
    // The Admin SDK also accepts queries inside a transaction; the group
    // domain uses that to count all members before changing a role.
    if (ref instanceof QueryBuilder) return ref.get(this.transactionId);
    return this.rest.getDocument(ref.path, this.transactionId);
  }

  set(ref: DocumentReference, data: Record<string, unknown>, options?: { merge?: boolean }): void {
    this.writes.push(buildWriteFromData(
      this.rest.resourceName(ref.path),
      data,
      { merge: options?.merge === true },
    ));
  }

  update(ref: DocumentReference, data: Record<string, unknown>): void {
    this.writes.push(buildUpdateWrite({
      resourceName: this.rest.resourceName(ref.path),
      data,
      currentDocument: { exists: true },
    }));
  }

  create(ref: DocumentReference, data: Record<string, unknown>): void {
    this.writes.push(buildUpdateWrite({
      resourceName: this.rest.resourceName(ref.path),
      data,
      currentDocument: { exists: false },
    }));
  }

  delete(ref: DocumentReference): void {
    this.writes.push({ delete: this.rest.resourceName(ref.path) });
  }
}

export async function createFirestoreGateway(
  env: FirestoreGatewayEnv,
  options: GatewayOptions = {},
): Promise<FirestoreRest> {
  const token = options.token ?? (
    !env.FIRESTORE_SERVICE_ACCOUNT_EMAIL ||
    !env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY
      ? null
      : await getGoogleAccessToken(
          env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
          env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"),
          [DATASTORE_SCOPE],
          options.fetcher,
        )
  );
  if (!token) throw new Error("Firestore service credentials are not configured.");
  return new FirestoreRest(env.FIREBASE_PROJECT_ID, token, options.fetcher);
}
