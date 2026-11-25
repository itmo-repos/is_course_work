import {test,expect} from '@playwright/test';
test.beforeEach(async({page})=>{
 await page.route('**/api/**',async route=>{
  const path=new URL(route.request().url()).pathname;
  if(path==='/api/auth/me')return route.fulfill({status:401});
  if(path==='/api/auth/csrf')return route.fulfill({json:{headerName:'X-CSRF',token:'test-token'}});
  if(path==='/api/samples/countries')return route.fulfill({json:[{code:'RU',name:'Russia'}]});
  if(path==='/api/samples')return route.fulfill({json:[]});
  if(path==='/api/auth/login')return route.fulfill({status:401});
  return route.fulfill({status:501});
 });
});
test('catalog shows empty state and switches language',async({page})=>{
 await page.goto('/catalog');await expect(page.getByRole('status').filter({hasText:'Образцы не найдены'})).toBeVisible();
 await page.getByRole('button',{name:'Сменить язык'}).click();await expect(page.getByRole('heading',{name:'Sample catalog'})).toBeVisible();
 await expect(page.getByRole('status').filter({hasText:'No samples found'})).toBeVisible();
});
test('failed login preserves input',async({page})=>{
 await page.goto('/login');await page.getByLabel('Email').fill('unknown@example.org');
 await page.getByLabel('Пароль',{exact:true}).fill('wrong-password');
 await page.getByRole('button',{name:'Войти',exact:true}).click();
 await expect(page.getByRole('main').getByRole('alert')).toHaveText('Неверный email или пароль');
 await expect(page.getByLabel('Email')).toHaveValue('unknown@example.org');
 await expect(page.getByLabel('Пароль',{exact:true})).toHaveValue('wrong-password');
});
test('catalog failure preserves filters',async({page})=>{
 await page.goto('/catalog');await expect(page.getByRole('status').filter({hasText:'Образцы не найдены'})).toBeVisible();
 await page.route('**/api/samples?**',route=>route.fulfill({status:500}));
 await page.getByLabel('Вид растения').fill('Triticum');await page.getByRole('button',{name:'Найти',exact:true}).click();
 await expect(page.getByRole('main').getByRole('alert')).toContainText('Не удалось загрузить каталог');
 await expect(page.getByLabel('Вид растения')).toHaveValue('Triticum');
});
test('employee ADMIN does not get curator navigation implicitly',async({page})=>{
 await page.route('**/api/auth/me',route=>route.fulfill({json:{id:1,type:'EMPLOYEE',email:'staff@example.org',roles:['ADMIN']}}));
 await page.goto('/workspace');await expect(page.getByRole('link',{name:'Администрирование',exact:true})).toBeVisible();
 await expect(page.getByRole('link',{name:'Приём и склад',exact:true})).toHaveCount(0);
});
test('successful login refreshes CSRF before logout',async({page})=>{
 let count=0;const requests:string[]=[];
 await page.route('**/api/auth/csrf',route=>route.fulfill({json:{headerName:'X-CSRF',token:++count===1?'before':'after'}}));
 await page.route('**/api/auth/login',async route=>{requests.push(route.request().headers()['x-csrf']);await route.fulfill({json:{id:2,type:'DEPOSITOR',email:'depositor@example.org',roles:[]}})});
 await page.route('**/api/auth/logout',async route=>{requests.push(route.request().headers()['x-csrf']);await route.fulfill({status:204})});
 await page.goto('/login');await page.getByLabel('Email').fill('depositor@example.org');await page.getByLabel('Пароль',{exact:true}).fill('password');
 await page.getByRole('button',{name:'Войти',exact:true}).click();await expect(page).toHaveURL(/workspace$/);
 await page.getByRole('button',{name:'Выйти',exact:true}).click();await expect(page.getByRole('link',{name:'Мои партии',exact:true})).toHaveCount(0);
 expect(requests).toEqual(['before','after']);
});
