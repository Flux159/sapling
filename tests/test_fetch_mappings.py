"""Tests for author maps and file maps.
"""
import os
import unittest

from mercurial import ui

import test_util
import fetch_command

class MapTests(test_util.TestBase):
    @property
    def authors(self):
        return os.path.join(self.tmpdir, 'authormap')

    @property
    def filemap(self):
        return os.path.join(self.tmpdir, 'filemap')

    def test_author_map(self, stupid=False):
        test_util.load_svndump_fixture(self.repo_path, 'replace_trunk_with_branch.svndump')
        authormap = open(self.authors, 'w')
        authormap.write("Augie=Augie Fackler <durin42@gmail.com>\n")
        authormap.close()
        fetch_command.fetch_revisions(ui.ui(),
                                      svn_url=test_util.fileurl(self.repo_path),
                                      hg_repo_path=self.wc_path,
                                      stupid=stupid,
                                      authors=self.authors)
        self.assertEqual(self.repo[0].user(),
                         'Augie Fackler <durin42@gmail.com>')
        self.assertEqual(self.repo['tip'].user(),
                        'evil@5b65bade-98f3-4993-a01f-b7a6710da339')

    def test_author_map_stupid(self):
        self.test_author_map(True)

    def test_author_map_closing_author(self, stupid=False):
        test_util.load_svndump_fixture(self.repo_path, 'replace_trunk_with_branch.svndump')
        authormap = open(self.authors, 'w')
        authormap.write("evil=Testy <test@test>")
        authormap.close()
        fetch_command.fetch_revisions(ui.ui(),
                                      svn_url=test_util.fileurl(self.repo_path),
                                      hg_repo_path=self.wc_path,
                                      stupid=stupid,
                                      authors=self.authors)
        self.assertEqual(self.repo[0].user(),
                         'Augie@5b65bade-98f3-4993-a01f-b7a6710da339')
        self.assertEqual(self.repo['tip'].user(),
                        'Testy <test@test>')

    def test_author_map_closing_author_stupid(self):
        self.test_author_map_closing_author(True)


def suite():
    return unittest.TestLoader().loadTestsFromTestCase(MapTests)
