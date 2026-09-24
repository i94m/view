import { test as base, Page } from '@playwright/test';

export const credentials = {
  email: process.env.VIEW_USERNAME || '',
  password: process.env.VIEW_PASSWORD || '',
};

// Login uses same-page redirect (NOT popup) — "Sign in with Microsoft" navigates to microsoftonline.com
async function doMicrosoftLogin(page: Page, email: string, password: string): Promise<void> {
  await page.getByText('Sign in with Microsoft').click();
  await page.waitForURL(/microsoftonline\.com/, { timeout: 15000 });
  await page.waitForLoadState('domcontentloaded');

  await page.locator('input[type="email"]').waitFor({ state: 'visible', timeout: 10000 });
  await page.locator('input[type="email"]').fill(email);
  await page.getByRole('button', { name: /next|继续|下一步/i }).click();

  await page.waitForSelector('input[type="password"]', { timeout: 10000 });
  await page.locator('input[type="password"]').fill(password);
  await page.getByRole('button', { name: /sign in|登录|登錄/i }).click();

  try {
    const staySignedIn = page.getByRole('button', { name: /yes|是|continue|继续/i });
    await staySignedIn.waitFor({ state: 'visible', timeout: 5000 });
    await staySignedIn.click();
  } catch { /* "Stay signed in?" prompt may not appear */ }

  // Match both hkdev2.ap.tkelevator.com and view-dev2.tkelevator.com.cn
  await page.waitForURL(/tkelevator\.com/, { timeout: 30000 });
  await page.waitForLoadState('domcontentloaded');
}

export async function login(
  page: Page,
  email: string = credentials.email,
  password: string = credentials.password
): Promise<void> {
  if (!email || !password) {
    throw new Error('请设置环境变量 VIEW_USERNAME 和 VIEW_PASSWORD');
  }

  await page.goto('/login.php?currentlanguage=en');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(2000);

  await doMicrosoftLogin(page, email, password);
}

export const test = base.extend<{ page: Page }>({
  page: async ({ page }, use) => {
    const email = credentials.email;
    const password = credentials.password;

    if (!email || !password) {
      throw new Error('请设置环境变量 VIEW_USERNAME 和 VIEW_PASSWORD');
    }

    let isLoggedIn = false;
    const originalGoto = page.goto.bind(page);

    page.goto = async (url: string, options?: Parameters<Page['goto']>[1]) => {
      const result = await originalGoto(url, options);
      await page.waitForLoadState('domcontentloaded');

      if (page.url().includes('login.php') && !isLoggedIn) {
        await page.waitForTimeout(2000);
        await doMicrosoftLogin(page, email, password);
        isLoggedIn = true;
        await originalGoto(url, { ...options, waitUntil: 'domcontentloaded' });
      }

      return result;
    };

    await use(page);
  },
});

export { expect } from '@playwright/test';
