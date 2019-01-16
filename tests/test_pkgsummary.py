import unittest
import datetime
import shutil
import tempfile
import os
import json

from piupartslib.pkgsummary import flaginfo
from piupartslib.pkgsummary import get_flag
from piupartslib.pkgsummary import worst_flag
from piupartslib.pkgsummary import SummaryException
from piupartslib.pkgsummary import new_summary
from piupartslib.pkgsummary import add_summary
from piupartslib.pkgsummary import read_summary
from piupartslib.pkgsummary import merge_summary
from piupartslib.pkgsummary import write_summary


class PkgSummaryTests(unittest.TestCase):

    def testSummFlaginfoStateDups(self):
        finfo = flaginfo
        states = sorted([y for x in finfo for y in finfo[x].states])
        nodups = sorted(list(set(states)))

        self.assertTrue('successfully-tested' in states)
        self.assertEqual(states, nodups)

    def testSummGetFlag(self):
        self.assertEqual('F', get_flag('failed-testing'))
        self.assertEqual('X', get_flag('dependency-does-not-exist'))
        self.assertEqual('P', get_flag('successfully-tested'))
        self.assertEqual('W', get_flag('waiting-to-be-tested'))

        with self.assertRaises(SummaryException):
            get_flag('bogus-state')

    def testSummWorstFlag(self):
        self.assertEqual('F', worst_flag('F'))
        self.assertEqual('P', worst_flag('P'))
        self.assertEqual('F', worst_flag('P', 'F'))
        self.assertEqual('F', worst_flag('F', 'F'))
        self.assertEqual('W', worst_flag('W', 'P'))
        self.assertEqual('F', worst_flag('W', 'P', 'F', 'X', '-'))

        with self.assertRaises(SummaryException):
            worst_flag('Z')


class PkgSummaryAddTests(unittest.TestCase):

    def setUp(self):
        self.summ = new_summary()

    def testSummNewSumm(self):
        # Verify any parameters which are depended on downstream

        self.assertEqual("Piuparts Package Test Results Summary", self.summ['_id'])
        self.assertEqual("1.0", self.summ['_version'])
        self.assertEqual({}, self.summ['packages'])

        thedate = datetime.datetime.strptime(self.summ['_date'], "%a %b %d %H:%M:%S UTC %Y")

    def testSummAddArgValidation(self):
        with self.assertRaises(SummaryException):
            add_summary(
                self.summ, 'foodist', 'foopkg', 'Z', 0, 'http://foo')
        with self.assertRaises(SummaryException):
            add_summary(
                self.summ, 'foodist', 'foopkg', 'X', 'bogus',
                'http://foo')
        with self.assertRaises(SummaryException):
            add_summary(
                self.summ, 'foodist', 'foopkg', 'X', 1, 'ittp://foo')

        add_summary(
            self.summ, 'foodist', 'foopkg', 'X', 1, 'http://foo')

    def testSummAddArgStorageFormat(self):
        # store non-overlapping entries

        add_summary(self.summ, 'dist', 'pkg', 'X', 0, 'http://foo')
        add_summary(
            self.summ, 'dist', 'pkg2', 'W', 1, 'http://foo2')
        add_summary(
            self.summ, 'dist2', 'pkg3', 'P', 2, 'http://foo3')
        self.assertEqual(
            ['X', 0, 'http://foo'],
            self.summ['packages']['pkg']['dist'])
        self.assertEqual(
            ['W', 1, 'http://foo2'],
            self.summ['packages']['pkg2']['dist'])
        self.assertEqual(
            ['P', 2, 'http://foo3'],
            self.summ['packages']['pkg3']['dist2'])

    def testSummAddOverwriteFlag(self):
        add_summary(self.summ, 'dist', 'pkg', 'X', 0, 'http://foo')
        add_summary(self.summ, 'dist', 'pkg', 'P', 0, 'http://foo2')
        self.assertEqual('X', self.summ['packages']['pkg']['dist'][0])
        self.assertEqual('http://foo', self.summ['packages']['pkg']['dist'][2])

        add_summary(self.summ, 'dist', 'pkg', 'F', 0, 'http://foo3')
        self.assertEqual('F', self.summ['packages']['pkg']['dist'][0])
        self.assertEqual('http://foo3', self.summ['packages']['pkg']['dist'][2])

    def testSummAddBlockCount(self):
        add_summary(self.summ, 'dist', 'pkg', 'X', 0, 'http://foo')
        add_summary(self.summ, 'dist', 'pkg', 'P', 1, 'http://foo')
        self.assertEqual(1, self.summ['packages']['pkg']['dist'][1])

        add_summary(self.summ, 'dist', 'pkg', 'F', 2, 'http://foo')
        self.assertEqual(2, self.summ['packages']['pkg']['dist'][1])

    def testSummMerge(self):
        add_summary(self.summ, 'dist', 'pkg', 'X', 0, 'http://foo')

        mergesumm = new_summary()

        merge_summary(mergesumm, self.summ)

        self.assertEqual(mergesumm['packages']['pkg']['dist'],
                         self.summ['packages']['pkg']['dist'])
        self.assertEqual(mergesumm['packages']['pkg']['dist'],
                         mergesumm['packages']['pkg']['overall'])


class PkgSummaryStorageTests(unittest.TestCase):

    def setUp(self):
        self.summ = new_summary()
        add_summary(self.summ, 'dist', 'pkg', 'X', 0, 'http://foo')

        self.tmpdir = tempfile.mkdtemp()

        self.tmpfilename = os.path.join(self.tmpdir, "foo.json")
        write_summary(self.summ, self.tmpfilename)

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def testSummFileRead(self):
        summ2 = read_summary(self.tmpfilename)

        self.assertEqual(self.summ, summ2)

    def testSummFileStorage(self):
        with open(self.tmpfilename, 'r') as fl:
            summ2 = json.load(fl)

        self.assertEqual(self.summ, summ2)
