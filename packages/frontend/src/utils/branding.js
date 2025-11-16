export function applyBranding(project) {
  if (typeof document === 'undefined' || !project?.project) {
    return;
  }

  const root = document.documentElement;
  const primary = project.project.primaryColor || '#1B4332';
  const accent = project.project.accentColor || '#95D5B2';
  const background = project.project.backgroundColor || '#081c15';

  root.style.setProperty('--brand-primary', primary);
  root.style.setProperty('--brand-accent', accent);
  root.style.setProperty('--brand-background', background);
}
