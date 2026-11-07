export function authenticateKirariService(
  request: Request,
  expected: {
    audience: string;
    serviceAccountEmail: string;
  },
  fetchImpl?: typeof fetch,
  nowSeconds?: number,
): Promise<boolean>;
