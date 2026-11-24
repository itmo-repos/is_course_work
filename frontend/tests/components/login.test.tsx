import {afterEach,expect,test,vi} from 'vitest';
import {render,screen,cleanup} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {Providers} from '@/components/providers';
import Login from '@/app/login/page';
import {api,ApiError} from '@/lib/api.mjs';
vi.mock('next/navigation',()=>({usePathname:()=>'/login',useRouter:()=>({push:vi.fn()})}));
afterEach(()=>{cleanup();vi.restoreAllMocks()});
test('401 preserves login values and renders an accessible alert',async()=>{
 vi.spyOn(api,'request').mockRejectedValue(new ApiError(401));
 vi.spyOn(api,'login').mockRejectedValue(new ApiError(401));
 render(<Providers><Login/></Providers>);const user=userEvent.setup();
 await user.type(screen.getByLabelText('Email'),'user@example.org');
 await user.type(screen.getByLabelText('Пароль'),'incorrect');
 await user.click(screen.getByRole('button',{name:'Войти'}));
 expect(await screen.findByRole('alert')).toHaveTextContent('Неверный email или пароль');
 expect(screen.getByLabelText('Email')).toHaveValue('user@example.org');
 expect(screen.getByLabelText('Пароль')).toHaveValue('incorrect');
});
