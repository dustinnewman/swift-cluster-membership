//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Cluster Membership open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Cluster Membership project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Cluster Membership project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ClusterMembership
import Logging
import NIO
import SWIM
@testable import SWIMNIO
import XCTest

final class SWIMNIOClusteredTests: RealClusteredXCTestCase {
    override var alwaysPrintCaptureLogs: Bool {
        true
    }

    // ==== ----------------------------------------------------------------------------------------------------------------
    // MARK: Black box tests, we let the nodes run and inspect their state via logs

    func test_real_peers_2_connect() throws {
        let (firstHandler, firstChannel) = self.makeClusterNode()
        let firstNode = firstHandler.shell.node

        let (secondHandler, secondChannel) = self.makeClusterNode() { settings in
            settings.initialContactPoints = [firstHandler.shell.node]
        }
        let secondNode = secondHandler.shell.node

        try self.capturedLogs(of: firstHandler.shell.node)
            .awaitLog(grep: #""swim/members/count": 2"#)
        try self.capturedLogs(of: secondNode)
            .awaitLog(grep: #""swim/members/count": 2"#)
    }

    func test_real_peers_2_connect_first_terminates() throws {
        let (firstHandler, firstChannel) = self.makeClusterNode() { settings in
            settings.pingTimeout = .milliseconds(100)
            settings.probeInterval = .milliseconds(500)
        }
        let firstNode = firstHandler.shell.node

        let (secondHandler, secondChannel) = self.makeClusterNode() { settings in
            settings.initialContactPoints = [firstHandler.shell.node]

            settings.pingTimeout = .milliseconds(100)
            settings.probeInterval = .milliseconds(500)
        }
        let secondNode = secondHandler.shell.node

        try self.capturedLogs(of: firstHandler.shell.node)
            .awaitLog(grep: #""swim/members/count": 2"#)

        // close first channel
        firstHandler.log.warning("Killing \(firstHandler.shell.node)...")
        secondHandler.log.warning("Killing \(firstHandler.shell.node)...")
        try firstChannel.close().wait()

        // we should get back down to a 1 node cluster
        // TODO: add same tests but embedded
        try self.capturedLogs(of: secondNode)
            .awaitLog(grep: #""swim/suspects/count": 1"#, within: .seconds(20))
    }

    func test_real_peers_5_connect() throws {
        let (first, _) = self.makeClusterNode()
        let (second, _) = self.makeClusterNode() { settings in
            settings.initialContactPoints = [first.shell.node]
        }
        let (third, _) = self.makeClusterNode() { settings in
            settings.initialContactPoints = [second.shell.node]
        }
        let (fourth, _) = self.makeClusterNode() { settings in
            settings.initialContactPoints = [third.shell.node]
        }
        let (fifth, _) = self.makeClusterNode() { settings in
            settings.initialContactPoints = [fourth.shell.node]
        }

        try [first, second, third, fourth, fifth].forEach { handler in
            do {
                try self.capturedLogs(of: handler.shell.node)
                    .awaitLog(
                        grep: #""swim/members/count": 5"#,
                        within: .seconds(10)
                    )
            } catch {
                throw TestError("Failed to find expected logs on \(handler.shell.node)", error: error)
            }
        }
    }
}

private struct TestError: Error {
    let message: String
    let error: Error

    init(_ message: String, error: Error) {
        self.message = message
        self.error = error
    }
}
