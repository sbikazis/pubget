export function authenticateKirariService(
  request: Request,
  expected: {
    audience: string;
    serviceAccountEmail: string;
    projectId: string;
    projectNumber: string;
  },
  fetchImpl?: typeof fetch,
  nowSeconds?: number,
): Promise<boolean>;
