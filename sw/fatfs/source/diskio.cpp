/*-----------------------------------------------------------------------*/
/* Low level disk I/O module SKELETON for FatFs     (C)ChaN, 2025        */
/*-----------------------------------------------------------------------*/
/* If a working storage control module is available, it should be        */
/* attached to the FatFs via a glue function rather than modifying it.   */
/* This is an example of glue functions to attach various exsisting      */
/* storage control modules to the FatFs module with a defined API.       */
/*-----------------------------------------------------------------------*/

#include "ff.h"			/* Basic definitions of FatFs */
#include "diskio.h"		/* Declarations FatFs MAI */

/* Example: Declarations of the platform and disk functions in the project */
#include <neosd_app.h>

extern "C"
{

	/*-----------------------------------------------------------------------*/
	/* Get Drive Status                                                      */
	/*-----------------------------------------------------------------------*/

	DSTATUS disk_status (BYTE pdrv)
	{
		return 0;
	}



	/*-----------------------------------------------------------------------*/
	/* Inidialize a Drive: User should call neosd_app_init manually before   */
	/*-----------------------------------------------------------------------*/

	DSTATUS disk_initialize (BYTE pdrv)
	{
		return 0;
	}



	/*-----------------------------------------------------------------------*/
	/* Read Sector(s)                                                        */
	/*-----------------------------------------------------------------------*/

	DRESULT disk_read (BYTE pdrv, BYTE *buff, LBA_t sector,	UINT count)
	{
		for (size_t i = 0; i < count; i++)
		{
			if (!neosd_app_read_block(sector + i, (uint32_t*)(buff + 512 * i)))
				return RES_ERROR;
		}

		return RES_OK;
	}



	/*-----------------------------------------------------------------------*/
	/* Write Sector(s)                                                       */
	/*-----------------------------------------------------------------------*/

	#if FF_FS_READONLY == 0

	DRESULT disk_write (
		BYTE pdrv,			/* Physical drive nmuber to identify the drive */
		const BYTE *buff,	/* Data to be written */
		LBA_t sector,		/* Start sector in LBA */
		UINT count			/* Number of sectors to write */
	)
	{
		DRESULT res;
		int result;

		switch (pdrv) {
		case DEV_RAM :
			// translate the arguments here

			result = RAM_disk_write(buff, sector, count);

			// translate the reslut code here

			return res;

		case DEV_MMC :
			// translate the arguments here

			result = MMC_disk_write(buff, sector, count);

			// translate the reslut code here

			return res;

		case DEV_USB :
			// translate the arguments here

			result = USB_disk_write(buff, sector, count);

			// translate the reslut code here

			return res;
		}

		return RES_PARERR;
	}

	#endif


	/*-----------------------------------------------------------------------*/
	/* Miscellaneous Functions                                               */
	/*-----------------------------------------------------------------------*/

	DRESULT disk_ioctl (BYTE pdrv, BYTE cmd, void *buff)
	{
		return RES_PARERR;
	}
}