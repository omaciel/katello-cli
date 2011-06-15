#!/usr/bin/python
#
# Katello Organization actions
# Copyright (c) 2010 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#

import os
import urlparse
from gettext import gettext as _
from pprint import pprint

from katello.client.api.ping import PingAPI
from katello.client.config import Config
from katello.client.core.base import Action, Command
from katello.client import constants

_cfg = Config()

# base ping action --------------------------------------------------------

class PingAction(Action):

    def __init__(self):
        super(PingAction, self).__init__()
        self.api = PingAPI()


# ping actions ------------------------------------------------------------

class Status(PingAction):

    description = _('get the status of the katello server')
    name = "ping"

    def setup_parser(self):
        return 0


    def run(self):
        status = self.api.ping()

        self.printer.addColumn('service')
        self.printer.addColumn('result')
        self.printer.addColumn('duration')
        self.printer.addColumn('message')

        self.printer.printHeader(_("Katello Staus"))
        if not self.has_option('grep'):
            print constants.STATUS_INFO % (status["result"])
            print

        details = status["status"]

        for key in details.keys():
            detail = details[key]
            detail['service'] = key

            if detail.has_key("duration_ms"):
                detail["duration"] = detail["duration_ms"] + "ms"
            self.printer.printItem(detail, " "*4)

        return os.EX_OK

# ping command ------------------------------------------------------------

class Ping(Command):

    description = _('Check the status of the server')
