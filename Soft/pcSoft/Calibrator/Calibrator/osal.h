#pragma once

#include <stdint.h>

#ifdef WIN32
#include "osal_win32.h"
#endif
#ifdef SYSBIOS
#include "osal_sysbios.h"
#endif
#ifdef LINUX
#include "osal_linux.h"
#endif
	
#define START_DECLARE_USER_MESSAGES(name) \
enum msg_user_ids_##name { \
    first_user_msg_##name = MSG_FIRST_USER,

#define DECLARE_USER_MESSAGE(MSG)   \
    MSG,

#define END_DECLARE_USER_MESSAGES(name) \
    last_user_msg_##name \
 };

typedef struct message_s {
	uint32_t type;
	uint32_t param;
} MESSAGE;

// osal com port
#define COM_SUCCESS				     0
#define COM_ERR_PORT_ALREADY_OPEN	-1
#define COM_ERR_DO_NOT_OPEN			-2
#define COM_ERR_NO_CHAR_RECEIVED	-3
#define COM_ERR_PORT_DO_NOT_EXIST	-4
#define COM_ERR_WRONG_CONFIG	    -5
#define COM_ERR_NO_RX_DATA			-6
#define COM_ERR_CREATE_THREAD		-7
typedef struct _com_config_type {
	uint32_t baud_rate;
	uint32_t byte_size; // number of bits/byte 4-8
	uint32_t parity;
	uint32_t stop_bits;
	uint32_t fl_sync_mode;
	uint32_t mode;
} com_config_type;

#define GPIO_IN  0
#define GPIO_OUT 1

#define GPIO_PULL_UP	0
#define GPIO_PULL_DOWN	1
#define GPIO_NO_PULL	2

#define GPIO_LOW  0
#define GPIO_HIGH 1

#define FILE_CURRENT_POSITION   ((size_t)(-1))

namespace osal {
    int com_open(int port_num, com_config_type *cfg);
    void com_close(void);
    uint32_t com_write(const void* buffer, uint32_t length);
 //   void com_printf(char* format, ...);
    uint32_t com_read(void* buffer, uint32_t length, uint32_t timeout, uint32_t* readedlen);
#if 0
    void master_spi_write(const void* buffer, uint32_t length);
    void master_spi_read(void* buffer, uint32_t length);
    void master_spi_transfer(const void* tx_buffer, void* rx_buffer, uint32_t length);

    void* file_open(const char* filename, bool write = false);
    size_t file_length(void* file);
    size_t file_read(void* file, uint8_t* buffer, size_t len, size_t position = FILE_CURRENT_POSITION);
    ///size_t file_read(void* file, uint8_t* buffer, size_t len);
    size_t file_write(void* file, uint8_t* buffer, size_t len, size_t position = FILE_CURRENT_POSITION);
    ///size_t file_write(void* file, uint8_t* buffer, size_t len);
    void file_close(void* file);

    void* alloc_phy2virt(int *fd, void *map_base, off_t target);
    void free_phy2virt(int fd, void *map_base);

    void gpio_open(int pin, int dir);
    void gpio_write(int pin, int value);
    int gpio_read(int pin);
    void gpio_close(int pin);
    int gpio_poll_open(int pin, const char *edge);
    int gpio_poll_get(int fd, int timeout);
    void gpio_poll_close(int fd);

    void _usleep(int us);
#endif
}
	
#define SUCCESS        0

