from pathlib import Path
import sys

def apply(store):
 p=store/'Dependencies/SideSign/Sources/Models/WatchBundleSupport.swift'
 s=p.read_text(encoding='utf-8'); anchor='public enum WatchBundleSupport {'
 assert s.count(anchor)==1
 s=s.replace(anchor,anchor+'''
    // Stable on repeated re-signing. Repair only Fairway's repeated suffix;
    // keep other applications' existing group container identifiers intact.
    public static func stableRefreshGroup(_ group: String, team: String) -> String {
        guard !team.isEmpty else { return group }
        let suffix = "." + team
        var base = group
        if group.hasPrefix("group.local.fairway.score.") {
            while base.hasSuffix(suffix) { base = String(base.dropLast(suffix.count)) }
            if base == "group.local.fairway.score" { return base + suffix }
        }
        return group.hasSuffix(suffix) ? group : group + suffix
    }
''');p.write_text(s,encoding='utf-8')
 p=store/'SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift';s=p.read_text(encoding='utf-8');anchor='        return groupIdentifier + "." + team.identifier';assert s.count(anchor)==1;s=s.replace(anchor,'        return WatchBundleSupport.stableRefreshGroup(groupIdentifier, team: team.identifier)');p.write_text(s,encoding='utf-8')
 p=store/'Dependencies/SideSign/Tests/SideSignTests/WatchSupportTests.swift';s=p.read_text(encoding='utf-8');anchor='final class WatchSupportTests: XCTestCase {';assert s.count(anchor)==1;s=s.replace(anchor,anchor+'''
    func testRepeatedRefreshGroupIsStableAndRepairsFairway() {
        let team = "TESTTEAM00"
        let original = "group.local.fairway.score"
        let once = original + "." + team
        let repeated = original + String(repeating: "." + team, count: 14)
        XCTAssertEqual(WatchBundleSupport.stableRefreshGroup(original, team: team), once)
        XCTAssertEqual(WatchBundleSupport.stableRefreshGroup(repeated, team: team), once)
        var current = once
        for _ in 0..<30 { current = WatchBundleSupport.stableRefreshGroup(current, team: team) }
        XCTAssertEqual(current, once)
        let other = "group.other." + team + "." + team
        XCTAssertEqual(WatchBundleSupport.stableRefreshGroup(other, team: team), other)
    }
''');p.write_text(s,encoding='utf-8')
if __name__ == '__main__': apply(Path(sys.argv[1]).resolve())
