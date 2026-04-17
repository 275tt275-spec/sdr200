/*
 * lcd.c
 *
 *  Created on: 17 апр. 2026 г.
 *      Author: VictorT
 */

#include "xil_cache.h" // Для очистки кэша
#include "xaxivdma.h"
#include "xparameters.h"
#include "lcd.h"

// Адрес в памяти, где лежит картинка (должен быть выровнен)
#define FRAME_BUFFER_ADDR  0x08000000
#define H_RES              1024
#define V_RES              768
#define BYTES_PER_PIXEL    4  // Для 32-bit (RGBA)

void lcd_init(void)
{
    XAxiVdma my_vdma;
    XAxiVdma_Config *config;
    XAxiVdma_DmaSetup read_config;

    // 1. Поиск конфигурации VDMA
    config = XAxiVdma_LookupConfig(XPAR_AXIVDMA_0_DEVICE_ID);

    // 2. Инициализация драйвера
    XAxiVdma_CfgInitialize(&my_vdma, config, config->BaseAddress);

    // 3. Настройка параметров чтения (Read Channel)
    read_config.VertSizeInput = V_RES;          // Кол-во строк
    read_config.HoriSizeInput = H_RES * BYTES_PER_PIXEL; // Кол-во байт в строке
    read_config.Stride = H_RES * BYTES_PER_PIXEL;       // Шаг между строками

    read_config.FrameDelay = 0;
    read_config.EnableCircularBuf = 1; // Зациклить чтение кадра
    read_config.EnableSync = 0;        // Внутренняя синхронизация
    read_config.PointNum = 0;
    read_config.EnableFrameCounter = 0;

    // Конфигурация канала чтения
    XAxiVdma_DmaConfig(&my_vdma, XAXIVDMA_READ, &read_config);

    // 4. Установка адреса кадра в памяти
    UINTPTR frame_addr = FRAME_BUFFER_ADDR;

    XAxiVdma_DmaSetBufferAddr(&my_vdma, XAXIVDMA_READ, &frame_addr);

    fill_test_pattern(FRAME_BUFFER_ADDR, H_RES, V_RES);

    // 5. Запуск VDMA
    XAxiVdma_DmaStart(&my_vdma, XAXIVDMA_READ);

    // Теперь VDMA начал выкачивать данные из 0x08000000 в поток AXI-Stream
}

void fill_test_pattern(u32 start_addr, int width, int height)
{
    u32 *frame_ptr = (u32 *)start_addr;
    u32 color;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // Создаем полосы: если x < 341 — красная, < 682 — зеленая, иначе — синяя
            if (x < (width / 3)) {
                color = 0x00FF0000; // Red (формат 0x00RRGGBB)
            } else if (x < (2 * width / 3)) {
                color = 0x0000FF00; // Green
            } else {
                color = 0x000000FF; // Blue
            }

            // Записываем пиксель в память
            frame_ptr[y * width + x] = color;
        }
    }

    // ВАЖНО: Очистка кэша данных.
    // Без этого VDMA может прочитать старые данные из DDR, а не те, что записал процессор.
    Xil_DCacheFlushRange(start_addr, width * height * 4);
}
