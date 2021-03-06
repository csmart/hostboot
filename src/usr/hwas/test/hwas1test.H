/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/usr/hwas/test/hwas1test.H $                               */
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
#ifndef __TESTTARGETING_H
#define __TESTTARGETING_H

/**
 *  @file testtargeting.H
 *
 *  @brief Unit tests for HWAS
 */

//******************************************************************************
// Includes
//******************************************************************************

// STD
#include <stdio.h>
#include <sys/time.h>

// CXXTEST
#include <cxxtest/TestSuite.H>
#include <hwpf/plat/fapiPlatAttributeService.H>
#include <fapiReturnCode.H>
#include <fapiAttributeIds.H>
#include <fapiAttributeService.H>
#include <errl/errlmanager.H>

#include <hwas/common/hwas.H>
#include <hwas/common/hwasCommon.H>
#include <targeting/common/commontargeting.H>

class HWAS1test: public CxxTest::TestSuite
{
public:


    /**
     * @brief   Write to all the attributes and then read them back.
     */
    void    testHWASReadWrite()
    {
        using namespace TARGETING;

        TARGETING::HwasState    l_orgHwasState, l_hwasState;
        TARGETING::TargetIterator l_pTarget;

        TS_TRACE( "testHWASReadWrite entry" );

        //  write a pattern to all HWAS attributes and then read them back
        for(    l_pTarget = TARGETING::targetService().begin();
                l_pTarget != TARGETING::targetService().end();
                ++l_pTarget
                )
        {
            //  save original state
            l_orgHwasState  =   l_pTarget->getAttr<ATTR_HWAS_STATE>();

            //  modify state
            l_hwasState     =   l_pTarget->getAttr<ATTR_HWAS_STATE>();
            l_hwasState.deconfiguredByEid     =   0x12345678;
            l_hwasState.poweredOn             =   true;
            l_hwasState.present               =   true;
            l_hwasState.functional            =   true;

            //  Now write the modified value back to Targeting.
            l_pTarget->setAttr<ATTR_HWAS_STATE>( l_hwasState );

            // fetch and test new values
            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().deconfiguredByEid
                                != 0x12345678 )
            {
                TS_FAIL( " deconfiguredByEid = 0x%x, should be 0x12345678",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().
                                deconfiguredByEid );
            }

            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().poweredOn != true )
            {
                TS_FAIL( "poweredOn = 0x%x, should be true",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().poweredOn );
            }

            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().present != true )
            {
                TS_FAIL( " present   = 0x%x should be true",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().present   );
            }

            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().functional != true )
            {
                TS_FAIL( " functional = 0x%x, should be true",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().functional );
            }

            //
            //  Now write the original value back.
            //
            l_pTarget->setAttr<ATTR_HWAS_STATE>( l_orgHwasState );

            // check that it got written back correctly
            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().poweredOn
                    != l_orgHwasState.poweredOn )
            {
                TS_FAIL( "poweredOn = 0x%x, not restored",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().poweredOn );
            }

            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().present
                    != l_orgHwasState.present )
            {
                TS_FAIL( " present   = 0x%x, not restored",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().present   );
            }

            if ( l_pTarget->getAttr<ATTR_HWAS_STATE>().functional
                    != l_orgHwasState.functional )
            {
                TS_FAIL( " functional = 0x%x, not restored",
                        l_pTarget->getAttr<ATTR_HWAS_STATE>().functional );
            }

        }

        TS_TRACE( "testHWASReadWrite exit" );
    }

    /**
     * @brief   test platReadIDEC
     */
    void testHWASplatReadIDEC()
    {
        using namespace TARGETING;

        TS_TRACE( "testHWASplatReadIDEC entry" );

        // call platReadIDEC with target that doesn't have an ID/EC
        errlHndl_t l_errl;

        Target* pSys;
        targetService().getTopLevelTarget(pSys);

        l_errl = HWAS::platReadIDEC(pSys);

        if (l_errl)
        {
            // error log is expected case, delete it
            delete l_errl;
        }
        else
        {
            TS_FAIL("testHWASplatReadIDEC>"
                    "No error from platReadIDEC(pSys).");
        }

        TS_TRACE( "testHWASplatReadIDEC exit" );
    }

    /**
     * @brief   test platReadPartialGood
     */
    void testHWASplatReadPartialGood()
    {
        using namespace TARGETING;

        TS_TRACE( "testHWASplatReadPartialGood entry" );

        // call platReadPartialGood with target that isn't in the VPD
        errlHndl_t l_errl;

        Target* pSys;
        targetService().getTopLevelTarget(pSys);
        uint8_t pgData[64];

        l_errl = HWAS::platReadPartialGood(pSys, pgData);

        if (l_errl)
        {
            // error log is expected case, delete it
            delete l_errl;
        }
        else
        {
            TS_FAIL("testHWASplatReadPartialGood>"
                    "No error from platReadPartialGood(pSys).");
        }

        TS_TRACE( "testHWASplatReadPartialGood exit" );
    }

};

#endif //
