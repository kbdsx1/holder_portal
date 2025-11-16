import project from '@config/project.config.json';

export const projectConfig = project;

export const projectName = project.project?.name || 'Holder Portal';
export const projectDescription = project.project?.description || '';
export const primaryColor = project.project?.primaryColor || '#1B4332';
export const accentColor = project.project?.accentColor || '#95D5B2';
export const tokenSymbol = project.rewards?.currency || 'TOKEN';
export const logoPath = project.project?.logoPath;

export function getProjectValue(path, fallback) {
  return path.split('.').reduce((acc, segment) => {
    if (acc && Object.prototype.hasOwnProperty.call(acc, segment)) {
      return acc[segment];
    }
    return undefined;
  }, project) ?? fallback;
}
