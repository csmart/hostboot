/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/include/sys/misc.h $                                      */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* COPYRIGHT International Business Machines Corp. 2011,2014              */
/*                                                                        */
/* Licensed under the Apache License, Version 2.0 (the "License");        */
/* you may not use this file except in compliance with the License.       */
/* You may obtain a copy of the License at                                */
/*                                                                        */
/*     http://www.apache.org/licenses/LICENSE-2.0                         */
/*                                                                        */
/* Unless required by applicable law or agreed to in writing, software    */
/* distributed under the License is distributed on an "AS IS" BASIS,      */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or        */
/* implied. See the License for the specific language governing           */
/* permissions and limitations under the License.                         */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
#ifndef __SYS_MISC_H
#define __SYS_MISC_H

#include <stdint.h>

/**
 *  @enum   p8SystemConsts
 *
 *  system-wide constants:
 *  - please add as necessary
 *
 */

enum    p8SystemConsts
{
    /// max possible processors in a P8 system
    P8_MAX_PROCS        =   8,
    /// max EX (cores available in a processor )
    P8_MAX_EX_PER_PROC  =   16,

};


/**
 * @enum ShutdownStatus
 *
 * Shutdown values for shutdown command.
 */

enum ShutdownStatus
{
    SHUTDOWN_STATUS_GOOD                = 0x01230000,
    SHUTDOWN_STATUS_UT_FAILED           = 0x01230001,
    SHUTDOWN_STATUS_ISTEP_FAILED        = 0x01230002,
    SHUTDOWN_STATUS_EXTINITSVC_FAILED   = 0x01230003,
    SHUTDOWN_STATUS_INITSVC_FAILED      = 0x01230004,
};

/**
 * @enum WinkleScopes
 *
 * Scope of the winkle operation.
 */
enum WinkleScope
{
    WINKLE_SCOPE_MASTER = 0x0,
    WINKLE_SCOPE_ALL = 0x1,
};

/**
 * HOMER layout offsets
 * see: HOMER_Image_Layout.odt
 */
/** OCC image is at the start of the HOMER layout */
#define HOMER_OFFSET_TO_OCC_IMG 0
/** Offset from HOMER to OCC Host Data Area */
#define HOMER_OFFSET_TO_OCC_HOST_DATA (MEGABYTE)
/** SLW image is 2MB into the HOMER layout */
#define HOMER_SLW_IMG_OFFSET (2*MEGABYTE)
/** SLW Image Max ouput size */
#define HOMER_MAX_SLW_IMG_SIZE_IN_MB 1


#ifdef __cplusplus
extern "C"
{
#endif

#ifdef __HIDDEN_SYSCALL_SHUTDOWN
/** @fn shutdown()
 *  @brief Shutdown all CPUs (hardware threads)
 *  @param[in] i_status         The status code to post
 *  @param[in] i_payload_base   The base address (target HRMOR) of the payload.
 *  @param[in] i_payload_entry  The offset from base address of the payload
 *                              entry-point.
 *  @param[in] i_payload_data   Data pointer fo the payload.  For standalone
 *                              Saphire this is the devtree
 *  @param[in[ i_masterHBInstance  Hostboot instance number. for multinode
 */
extern "C" void shutdown(uint64_t i_status,
                         uint64_t i_payload_base,
                         uint64_t i_payload_entry,
                         uint64_t i_payload_data,
                         uint64_t i_masterHBInstance);
#endif

/** @enum ProcessorCoreType
 *  @brief Enumeration of the different supported processor cores.
 */
enum ProcessorCoreType
{
    /** Power8 "Murano" (low-end) core */
    CORE_POWER8_MURANO,
    /** Power8 "Venice" (high-end) core */
    CORE_POWER8_VENICE,
    /** Power8 "Naples" core */
    CORE_POWER8_NAPLES,

    CORE_UNKNOWN,
};

/** @fn cpu_core_type()
 *  @brief Determine the procesore core type.
 *
 *  @return ProcessorCoreType - Value from enumeration for this core.
 */
ProcessorCoreType cpu_core_type();

/** @fn cpu_dd_level()
 *  @brief Determine the processor DD level.
 *
 *  @return 1 byte DD level as <major nibble, minor nibble>.
 */
uint8_t cpu_dd_level();

/** @fn cpu_thread_count()
 *  @brief Get the number of available threads per cpu for this proctype
 *  @return # of threads per cpu
 */
size_t cpu_thread_count();

/** @fn cpu_start_core
 *  @brief Have the kernel start a new core.
 *
 *  @param[in] pir - PIR value of the first thread on the core.
 *  @param[in] i_threads - Bitstring of threads to enable (left-justified).
 *
 *  @note The kernel will start all threads on the requested core even
 *        though the callee only requests with a single PIR value.
 *
 *  @return 0 or -(errno) on failure.
 *
 *  @retval -ENXIO - The core ID was outside of the range the kernel is
 *                   prepared to support.
 */
int cpu_start_core(uint64_t pir,uint64_t i_threads);

/**
 * @enum CpuSprNames
 *
 * Names for SPR registers for cpu_spr_value().
 */
enum CpuSprNames
{
    CPU_SPR_MSR,
    CPU_SPR_LPCR,
    CPU_SPR_HRMOR,
};

/** @fn cpu_spr_value
 *  @brief Reads the kernel-desired value for an SPR.
 *
 *  This is used, for instance, in building a sleep-winkle image.
 *
 *  @return The desired value of the SPR register.
 */
uint64_t cpu_spr_value(CpuSprNames spr);

/** @fn cpu_master_winkle
 *  @brief Winkle the master core so runtime SLW image can be applied.
 *
 *  This requires that the master core is the only one executing instructions.
 *  Will execute the winkle instruction on all running threads and return when
 *  an IPI is receieved on the master thread of the core.
 *
 *  @retval 0 - Success
 *  @retval -EDEADLK - Cores other than the master are already running.
 *
 *  @note This function will migrate the task to the master thread and in the
 *        process will unset any task affinity.  See task_affinity_unpin().
 */
int cpu_master_winkle();

/** @fn cpu_all_winkle
 *  @brief Winkle all the threads.
 *
 *  This is used in multi-node systems to quiesce all the cores in a drawer
 *  prior to the fabric being stitched together.
 *
 *  @retval 0 - Success
 *
 *  @note This function will migrate the task to the master thread and in the
 *        process will unset any task affinity.  See task_affinity_unpin().
 */
int cpu_all_winkle();

/** @fn cpu_crit_assert
 *  @brief Forces a Terminate Immediate after a crit-assert is issued
 *  @param[in] i_failAddr - value in the linkRegister of the address
 *           of where the fail ocured.
 *
 *  @return none
 */
void cpu_crit_assert(uint64_t i_failAddr);

#ifdef __cplusplus
}
#endif

#endif
