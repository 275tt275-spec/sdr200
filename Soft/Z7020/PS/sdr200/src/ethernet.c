/*
 * ethernet.c
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#include <string.h>
#include <stdlib.h>

#include "xparameters.h"
#include "netif/xadapter.h"
#include "xil_printf.h"
#include "lwip/init.h"
#include "lwip/inet.h"
#include "lwip/netif.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "lwip/tcpip.h"
#if (LWIP_DHCP == 1)
#include "lwip/dhcp.h"
#endif

#include "ethernet.h"
#include "hw.h"
#include "eeprom.h"
#include "KenwoodCmd.h"

struct netif server_netif;
static volatile int nw_thread_done = 0;
struct udp_pcb *pcb;
static uint32_t mServerIP = 0;
static uint16_t mServerIQPort = PORT_DDC0_DEFAULT;
#define ETH_LINK_DETECT_INTERVAL	250
static volatile int mEnableDDC = 0;
static s_extio extioAnswer;

typedef struct {
	struct pbuf *p;
	ip_addr_t dst_ip;
	uint16_t dst_port;
} udp_send_msg_t;

extern void link_detect_thread(void *p);
static void network_thread(void *p);
static void ethernet_thread(void *p);
static void ethernet_application(void);
static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw);
static void print_ip(char *msg, ip_addr_t *ip);
static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw);

void ethernet_init(void)
{
	sys_thread_new("ethernet_thread", (void(*)(void*))ethernet_thread, NULL,
			MAIN_THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);

	extioAnswer.cmd = EXTIO_COMMAND_SEARCH;
}

/* Колбэк для безопасной отправки UDP из контекста tcpip_thread */
static void udp_send_cb(void *arg)
{
	udp_send_msg_t *msg = (udp_send_msg_t *)arg;
	if (msg != NULL) {
		if (pcb != NULL && msg->p != NULL) {
			err_t err = udp_sendto(pcb, msg->p, &msg->dst_ip, msg->dst_port);
			if (err != ERR_OK) {
				xil_printf("UDP send error: %d\r\n", err);
			}
		}
		if (msg->p != NULL) {
			pbuf_free(msg->p);
		}
		mem_free(msg);
	}
}

int ethernet_SendUdp(uint32_t destIp, uint16_t destPort, uint8_t* buf, uint32_t len)
{
	if (pcb == NULL) {
		return ERR_CONN;
	}

	struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, len, PBUF_POOL);
	if (!p) {
		xil_printf("Error allocating pbuf\r\n");
		return ERR_MEM;
	}
	memcpy(p->payload, buf, len);

	udp_send_msg_t *msg = (udp_send_msg_t *)mem_malloc(sizeof(udp_send_msg_t));
	if (!msg) {
		pbuf_free(p);
		xil_printf("Error allocating udp_send_msg\r\n");
		return ERR_MEM;
	}

	msg->p = p;
	msg->dst_ip.addr = destIp;
	msg->dst_port = destPort;

	if (tcpip_try_callback(udp_send_cb, msg) != ERR_OK) {
		pbuf_free(p);
		mem_free(msg);
		return ERR_MEM;
	}

	return ERR_OK;
}

void ethernet_SendIQ(uint8_t* buf, uint32_t len)
{
	if ((mServerIP != 0) && (mEnableDDC == 1))
	{
		ethernet_SendUdp(mServerIP, mServerIQPort, buf, len);
	}
}

static void ethernet_deinit_cb(void *arg)
{
	struct netif *netif = &server_netif;
	if (pcb != NULL) {
		udp_remove(pcb);
		pcb = NULL;
	}
	netif_set_down(netif);
}

void ethernet_deinit(void)
{
	tcpip_callback(ethernet_deinit_cb, NULL);
}

/** Receive data on a udp session (выполняется внутри tcpip_thread) */
static void udp_recv_traffic(void *arg, struct udp_pcb *tpcb,
		struct pbuf *p, const ip_addr_t *addr, u16_t port)
{
	if (p == NULL) {
		return;
	}

	uint64_t value64;
	uint32_t value32;
	uint16_t searchPort;
	s_extio* pExtio = (s_extio*)p->payload;

	switch(pExtio->cmd)
	{
	case EXTIO_COMMAND_SEARCH:
	{
		ip_addr_t *ip = &server_netif.ip_addr;
		xil_printf("udp_recv_traffic: EXTIO_COMMAND_SEARCH\n");
		mServerIP = addr->addr;
		searchPort = atoi((char*)&pExtio->payload[6]);

		sprintf((char*)extioAnswer.payload, "SDR200IP%d.%d.%d.%d:%d", ip4_addr1(ip), ip4_addr2(ip),
					ip4_addr3(ip), ip4_addr4(ip), UDP_SERVER_PORT_IN);

		/* Внутри udp_recv_traffic мы уже в контексте tcpip_thread, можно отправить напрямую */
		struct pbuf *ans_p = pbuf_alloc(PBUF_TRANSPORT, sizeof(extioAnswer), PBUF_POOL);
		if (ans_p) {
			memcpy(ans_p->payload, &extioAnswer, sizeof(extioAnswer));
			udp_sendto(pcb, ans_p, addr, searchPort);
			pbuf_free(ans_p);
		}
		break;
	}
	case EXTIO_COMMAND_STARTHW:
	{
		xil_printf("udp_recv_traffic: EXTIO_COMMAND_STARTHW\n");
		mEnableDDC = 1;
		mServerIP = addr->addr;
		memcpy(&mServerIQPort, pExtio->payload, sizeof(mServerIQPort));

		struct pbuf *ans_p = pbuf_alloc(PBUF_TRANSPORT, p->len, PBUF_POOL);
		if (ans_p) {
			memcpy(ans_p->payload, p->payload, p->len);
			udp_sendto(pcb, ans_p, addr, port);
			pbuf_free(ans_p);
		}
		break;
	}
	case EXTIO_COMMAND_STOPHW:
		xil_printf("udp_recv_traffic: EXTIO_COMMAND_STOPHW\n");
		mEnableDDC = 0;
		break;
	case EXTIO_COMMAND_SETHWLO:
		memcpy(&value64, pExtio->payload, sizeof(value64));
		e_vars->vfoA = (uint32_t)value64;
		hw_SetRXAFreq(e_vars->vfoA);
		hw_SetExtAmpFreq(e_vars->vfoA);
		kenwood_SetFrequency((uint32_t)value64);
		eeprom_vars_changed();
		break;
	case EXTIO_COMMAND_SETATT:
		memcpy(&value32, pExtio->payload, sizeof(value32));
		switch(value32)
		{
		case 0: e_vars->RXAATT = 0; break;
		case 1: e_vars->RXAATT = 10; break;
		case 2: e_vars->RXAATT = 20; break;
		case 3: e_vars->RXAATT = 30; break;
		}
		hw_SetRXAAtt((float)e_vars->RXAATT);
		eeprom_vars_changed();
		break;
	case EXTIO_COMMAND_SETAGC:
		memcpy(&value32, pExtio->payload, sizeof(value32));
		hw_SetAGC(value32);
		e_vars->AGCType = value32;
		eeprom_vars_changed();
		break;
	case EXTIO_COMMAND_SETMODE:
		memcpy(&value32, pExtio->payload, sizeof(value32));
		hw_SetRXAMode(value32);
		hw_SetTXAMode(value32);
		kenwood_SetMode(value32);
		e_vars->mode = value32;
		eeprom_vars_changed();
		break;
	}

	pbuf_free(p);
}

static void ethernet_application_cb(void *arg)
{
	err_t err;

	/* Create Server PCB */
	pcb = udp_new();
	if (!pcb) {
		xil_printf("UDP server: Error creating PCB. Out of Memory\r\n");
		return;
	}

	err = udp_bind(pcb, IP_ADDR_ANY, UDP_SERVER_PORT_IN);
	if (err != ERR_OK) {
		xil_printf("UDP server: Unable to bind to port");
		xil_printf(" %d: err = %d\r\n", UDP_SERVER_PORT_IN, err);
		udp_remove(pcb);
		pcb = NULL;
		return;
	}

	xil_printf("UDP server: Bind port %d\r\n", UDP_SERVER_PORT_IN);

	/* specify callback to use for incoming connections */
	udp_recv(pcb, udp_recv_traffic, NULL);
}

static void ethernet_application(void)
{
	tcpip_callback(ethernet_application_cb, NULL);
}

#if (LWIP_DHCP == 1)
static void dhcp_restart_cb(void *arg)
{
	struct netif *netif = (struct netif *)arg;
	dhcp_stop(netif);
	netif_set_addr(netif, IP4_ADDR_ANY4, IP4_ADDR_ANY4, IP4_ADDR_ANY4);
	dhcp_start(netif);
}

static void dhcp_stop_cb(void *arg)
{
	struct netif *netif = (struct netif *)arg;
	dhcp_stop(netif);
	netif_set_addr(netif, IP4_ADDR_ANY4, IP4_ADDR_ANY4, IP4_ADDR_ANY4);
}

static void dhcp_fallback_default_cb(void *arg)
{
	struct netif *netif = (struct netif *)arg;
	ip_addr_t ip, mask, gw;

	dhcp_stop(netif);
	assign_default_ip(&ip, &mask, &gw);
	netif_set_addr(netif, &ip, &mask, &gw);
	print_ip_settings(&netif->ip_addr, &netif->netmask, &netif->gw);
}
#else
static void static_ip_cb(void *arg)
{
	struct netif *netif = (struct netif *)arg;
	ip_addr_t ip, mask, gw;

	assign_default_ip(&ip, &mask, &gw);
	netif_set_addr(netif, &ip, &mask, &gw);
	print_ip_settings(&netif->ip_addr, &netif->netmask, &netif->gw);
}
#endif

static void ethernet_thread(void *p)
{
#if (LWIP_DHCP == 1)
	int mscnt = 0;
	u8_t prev_link_state = 0;
	u8_t dhcp_active = 0;
#endif

	/* initialize lwIP before calling sys_thread_new */
	lwip_init();

	/* any thread using lwIP should be created using sys_thread_new */
	sys_thread_new("nw_thread", network_thread, NULL,
			THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);

	/* wait for nw thread to finish initialization */
	while (!nw_thread_done)
		vTaskDelay(pdMS_TO_TICKS(100));

	/* Запускаем UDP сервер */
	ethernet_application();

#if (LWIP_DHCP == 1)
	while (1) {
		vTaskDelay(pdMS_TO_TICKS(DHCP_FINE_TIMER_MSECS));

		u8_t curr_link_state = netif_is_link_up(&server_netif);

		/* 1. Кабель подключен или линк только что поднялся */
		if (curr_link_state && !prev_link_state) {
			xil_printf("Ethernet link UP. Starting DHCP...\r\n");
			tcpip_callback(dhcp_restart_cb, &server_netif);
			mscnt = 0;
			dhcp_active = 1;
		}
		/* 2. Кабель отключен */
		else if (!curr_link_state && prev_link_state) {
			xil_printf("Ethernet link DOWN.\r\n");
			tcpip_callback(dhcp_stop_cb, &server_netif);
			dhcp_active = 0;
			mEnableDDC = 0;
		}

		/* 3. Мониторинг получения адреса по DHCP */
		if (curr_link_state && dhcp_active) {
			if (server_netif.ip_addr.addr != 0) {
				xil_printf("DHCP request success\r\n");
				print_ip_settings(&server_netif.ip_addr, &server_netif.netmask, &server_netif.gw);
				dhcp_active = 0;
			} else {
				mscnt += DHCP_FINE_TIMER_MSECS;
				if (mscnt >= 10000) {
					xil_printf("ERROR: DHCP request timed out\r\n");
					tcpip_callback(dhcp_fallback_default_cb, &server_netif);
					dhcp_active = 0;
				}
			}
		}

		prev_link_state = curr_link_state;
	}
#else
	tcpip_callback(static_ip_cb, &server_netif);
	vTaskDelete(NULL);
#endif
}

static void network_thread(void *p)
{
	/* the mac address of the board. this should be unique per board */
	u8 mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

	/* Add network interface to the netif_list, and set it as default */
	if (!xemac_add(&server_netif, NULL, NULL, NULL,
			mac_ethernet_address, PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\r\n");
		vTaskDelete(NULL);
		return;
	}

	netif_set_default(&server_netif);

	/* specify that the network if is up */
	netif_set_up(&server_netif);

	/* start packet receive thread - required for lwIP operation */
	sys_thread_new("xemacif_input_thread",
			(void(*)(void*))xemacif_input_thread, &server_netif,
			THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
	/* Start thread to detect link periodically for Hot Plug autodetect */
	sys_thread_new("link_detect_thread", link_detect_thread, &server_netif,
			THREAD_STACKSIZE, tskIDLE_PRIORITY);

	nw_thread_done = 1;
	vTaskDelete(NULL);
}

static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
	int err;

	xil_printf("Configuring default IP %s\r\n", DEFAULT_IP_ADDRESS);
	err = inet_aton(DEFAULT_IP_ADDRESS, ip);
	if(!err)
		xil_printf("Invalid default IP address: %d\r\n", err);

	err = inet_aton(DEFAULT_IP_MASK, mask);
	if(!err)
		xil_printf("Invalid default IP MASK: %d\r\n", err);

	err = inet_aton(DEFAULT_GW_ADDRESS, gw);
	if(!err)
		xil_printf("Invalid default gateway address: %d\r\n", err);
}

static void print_ip(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf("%d.%d.%d.%d\r\n", ip4_addr1(ip), ip4_addr2(ip),
	ip4_addr3(ip), ip4_addr4(ip));
}

static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
	print_ip("Board IP:       ", ip);
	print_ip("Netmask :       ", mask);
	print_ip("Gateway :       ", gw);
	xil_printf("\r\n");
}
