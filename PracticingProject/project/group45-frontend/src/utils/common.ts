import SparkMD5 from 'spark-md5';
import { $t } from '@/locales';
import dayjs from 'dayjs';

/**
 * Format date string or timestamp to readable format
 *
 * @param date - Date string, number timestamp, or Date object
 * @param template - dayjs format template (default: 'YYYY-MM-DD HH:mm:ss')
 */
export function formatDate(date?: string | number | Date, template = 'YYYY-MM-DD HH:mm:ss'): string {
  if (!date) return '';
  return dayjs(date).format(template);
}

/**
 * Transform record to option
 *
 * @example
 *   ```ts
 *   const record = {
 *     key1: 'label1',
 *     key2: 'label2'
 *   };
 *   const options = transformRecordToOption(record);
 *   // [
 *   //   { value: 'key1', label: 'label1' },
 *   //   { value: 'key2', label: 'label2' }
 *   // ]
 *   ```;
 *
 * @param record
 */
export function transformRecordToOption<T extends Record<string, string>>(record: T) {
  return Object.entries(record).map(([value, label]) => ({
    value,
    label
  })) as CommonType.Option<keyof T, T[keyof T]>[];
}

/**
 * Translate options
 *
 * @param options
 */
export function translateOptions(options: CommonType.Option<string, App.I18n.I18nKey>[]) {
  return options.map(option => ({
    ...option,
    label: $t(option.label)
  }));
}

/**
 * Toggle html class
 *
 * @param className
 */
export function toggleHtmlClass(className: string) {
  function add() {
    document.documentElement.classList.add(className);
  }

  function remove() {
    document.documentElement.classList.remove(className);
  }

  return {
    add,
    remove
  };
}

/** Convert file size to human-readable format (K/M/G) */
export function fileSize(size: number) {
  if (size < 1024 * 1024) {
    return `${(size / 1024).toFixed(2)}K`;
  }
  if (size < 1024 * 1024 * 1024) {
    return `${(size / 1024 / 1024).toFixed(2)}M`;
  }
  return `${(size / 1024 / 1024 / 1024).toFixed(2)}G`;
}

/** Get file extension from filename */
export function getFileExt(fileName: string) {
  if (!fileName) return '';
  return fileName.split('.').pop();
}

/** Calculate MD5 hash of a File */
export async function calculateMD5(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunkSizeBytes = 5 * 1024 * 1024; // 5MB
    const spark = new SparkMD5.ArrayBuffer();
    const reader = new FileReader();

    let currentChunk = 0;

    const loadNext = () => {
      const start = currentChunk * chunkSizeBytes;
      const end = Math.min(start + chunkSizeBytes, file.size);

      if (start >= file.size) {
        resolve(spark.end());
        return;
      }

      const blob = file.slice(start, end);
      reader.readAsArrayBuffer(blob);
    };

    reader.onload = e => {
      spark.append(e.target?.result as ArrayBuffer);
      currentChunk += 1;
      loadNext();
    };

    reader.onerror = () => reject(new Error('文件读取失败'));
    loadNext();
  });
}
