export function applyBranding(project) {
  if (typeof document === 'undefined' || !project?.project) {
    return;
  }

  const root = document.documentElement;
  const primary = project.project.primaryColor || '#000000';
  const accent = project.project.accentColor || '#FFD700';
  const background = project.project.backgroundColor || '#0a0a0a';

  root.style.setProperty('--brand-primary', primary);
  root.style.setProperty('--brand-accent', accent);
  root.style.setProperty('--brand-background', background);
}
