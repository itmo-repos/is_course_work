import type { User } from './types';

type Destination = {
  href: string;
  ru: string;
  en: string;
  visible?: (user: User | null) => boolean;
};

const destinations: Destination[] = [
  { href: '/', ru: 'О хранилище', en: 'About' },
  { href: '/catalog', ru: 'Каталог', en: 'Catalog' },
  { href: '/register', ru: 'Регистрация', en: 'Registration' },
  { href: '/workspace', ru: 'Личный кабинет', en: 'Workspace', visible: Boolean },
  { href: '/workspace/batches', ru: 'Мои партии', en: 'My batches', visible: user => user?.type === 'DEPOSITOR' },
  { href: '/workspace/withdrawals', ru: 'Изъятия', en: 'Withdrawals', visible: user => user?.type === 'DEPOSITOR' },
  { href: '/workspace/intake', ru: 'Приём и склад', en: 'Intake and storage', visible: hasRole('CURATOR') },
  { href: '/workspace/climate', ru: 'Климат', en: 'Climate', visible: hasRole('ENGINEER', 'ADMIN') },
  { href: '/workspace/access', ru: 'Пропуска', en: 'Access passes', visible: hasRole('SECURITY', 'ADMIN') },
  { href: '/workspace/admin', ru: 'Администрирование', en: 'Administration', visible: hasRole('ADMIN') },
  { href: '/workspace/reports', ru: 'Отчёты и аудит', en: 'Reports and audit', visible: hasRole('ADMIN') },
];

function hasRole(...roles: string[]) {
  return (user: User | null) => roles.some(role => user?.roles.includes(role));
}

export function navigationFor(user: User | null) {
  return destinations.filter(link => !link.visible || link.visible(user));
}
