import imageCompression from 'browser-image-compression';

export const COMPRESSION_CONFIG = {
    maxSizeMB: 0.35,           // Target 350KB (matches backend TARGET_FILE_SIZE_KB)
    maxWidthOrHeight: 1280,   // Matches backend OPTIMAL_MAX_DIMENSION
    useWebWorker: true,
    fileType: 'image/webp'    // Use WebP for better efficiency
};

/**
 * Compresses an image file.
 * @param file The file to compress
 * @returns A promise that resolves to the compressed file
 */
export async function compressImage(file: File): Promise<File> {
    if (!file.type.startsWith('image/')) {
        return file;
    }

    try {
        console.log(`📉 [COMPRESS] Starting: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)}MB)...`);
        const compressedBlob = await imageCompression(file, COMPRESSION_CONFIG as any);
        
        // Re-create File object with correct extension if it was changed to webp
        let fileName = file.name;
        if (COMPRESSION_CONFIG.fileType === 'image/webp') {
            const nameParts = fileName.split('.');
            if (nameParts.length > 1) {
                nameParts[nameParts.length - 1] = 'webp';
                fileName = nameParts.join('.');
            } else {
                fileName = `${fileName}.webp`;
            }
        }

        const compressedFile = new File([compressedBlob], fileName, {
            type: compressedBlob.type,
            lastModified: Date.now()
        });

        console.log(`📉 [COMPRESS] Success: ${file.name} -> ${fileName} (${(compressedFile.size / 1024).toFixed(2)}KB)`);
        return compressedFile;
    } catch (error) {
        console.error(`❌ [COMPRESS] Failed for ${file.name}, using original:`, error);
        return file;
    }
}

/**
 * Compresses multiple images in parallel.
 * @param files Array of files to compress
 * @param onProgress Optional callback for progress updates
 * @returns A promise that resolves to an array of compressed files
 */
export async function compressImagesParallel(
    files: File[],
    onProgress?: (index: number, total: number) => void
): Promise<File[]> {
    const total = files.length;
    let completed = 0;

    const compressionPromises = files.map(async (file, index) => {
        const compressed = await compressImage(file);
        completed++;
        if (onProgress) {
            onProgress(completed, total);
        }
        return compressed;
    });

    return Promise.all(compressionPromises);
}
