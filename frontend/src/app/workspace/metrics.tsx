export function Metrics({ items }: { items: { label: string; value: number }[] }) {
  return <dl className="workspace-metrics">
    {items.map(item => <div key={item.label}><dt>{item.label}</dt><dd>{item.value}</dd></div>)}
  </dl>;
}
