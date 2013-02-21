prefix = /usr/local
sbindir = $(prefix)/sbin
sharedir = $(prefix)/share
mandir = $(sharedir)/man
man1dir = $(mandir)/man1
libdir = $(prefix)/lib
docdir = $(prefix)/share/doc/piuparts/
site26 = $(libdir)/python2.6/dist-packages
site27 = $(libdir)/python2.7/dist-packages
htdocsdir	 = $(sharedir)/piuparts/htdocs
etcdir = $(prefix)/etc

distribution=${shell dpkg-parsechangelog | sed -n 's/^Distribution: *//p'}
ifeq ($(distribution),UNRELEASED)
version		:= ${shell echo "`dpkg-parsechangelog | sed -n 's/^Version: *//p'`~`date +%Y%m%d%H%M`~`git describe --dirty`"}
else
version		:= ${shell dpkg-parsechangelog | sed -n 's/^Version: *//p'}
endif


all: install install-doc

build-doc:
	a2x --copy -a toc -a toclevels=3 -f xhtml -r /etc/asciidoc/ README.txt
	a2x -f manpage piuparts.1.txt
	a2x --copy -f xhtml piuparts.1.txt

install-doc:
	install -d $(DESTDIR)$(docdir)/
	for file in README.txt README.html docbook-xsl.css ; do \
	    install -m 0644 $$file $(DESTDIR)$(docdir)/ ; done
	install -d $(DESTDIR)$(man1dir)
	install -m 0644 piuparts.1 $(DESTDIR)$(man1dir)/
	gzip -9f $(DESTDIR)$(man1dir)/piuparts.1
	install -m 0644 piuparts.1.html $(DESTDIR)$(docdir)/

install-conf:
	install -d $(DESTDIR)$(etcdir)/piuparts
	install -m 0644 conf/piuparts.conf.sample $(DESTDIR)$(etcdir)/piuparts/piuparts.conf

	install -d $(DESTDIR)$(etcdir)/cron.d
	install -m 0644 conf/crontab-master $(DESTDIR)$(etcdir)/cron.d/piuparts-master
	install -m 0644 conf/crontab-slave $(DESTDIR)$(etcdir)/cron.d/piuparts-slave
	sed -i -r '/^[^#]+/s/^/#/' $(DESTDIR)$(etcdir)/cron.d/piuparts-*

	install -d $(DESTDIR)$(etcdir)/sudoers.d
	install -m 440 conf/piuparts.sudoers $(DESTDIR)$(etcdir)/sudoers.d/piuparts
	sed -i -r '/^[^#]+/s/^/#/' $(DESTDIR)$(etcdir)/sudoers.d/piuparts

	install -d $(DESTDIR)$(etcdir)/apache2/conf.d
	install -m 0644 conf/piuparts.apache $(DESTDIR)$(etcdir)/apache2/conf.d/

install-conf-4-running-from-git:
	install -d $(DESTDIR)$(etcdir)/piuparts
	install -m 0644 conf/crontab-master $(DESTDIR)$(etcdir)/piuparts/
	install -m 0644 conf/crontab-slave $(DESTDIR)$(etcdir)/piuparts/
	install -m 0644 instances/forward.* $(DESTDIR)$(etcdir)/piuparts/
	install -m 0644 instances/piuparts.conf.* $(DESTDIR)$(etcdir)/piuparts/
	install -d $(DESTDIR)$(sharedir)/piuparts/slave
	install -m 0755 update-piuparts-setup $(DESTDIR)$(sharedir)/piuparts/slave/

SCRIPTS_TEMPLATES	 = $(wildcard master-bin/*.in slave-bin/*.in conf/*.in)
SCRIPTS_GENERATED	 = $(SCRIPTS_TEMPLATES:.in=)

%: %.in
	sed -r \
		-e "s%@sharedir@%$(sharedir)%g" \
		$< > $@

python-syntax-check:
	@set -e -x; $(foreach py,$(wildcard *.py piupartslib/*.py),python -m py_compile $(py);)

build: python-syntax-check $(SCRIPTS_GENERATED)
	@set -e -x ; \
		for file in piuparts piuparts-slave piuparts-master piuparts-report piuparts-analyze; do \
		sed -e 's/__PIUPARTS_VERSION__/$(version)/g' $$file.py > $$file ; done

install:
	install -d $(DESTDIR)$(sbindir)
	install -m 0755 piuparts $(DESTDIR)$(sbindir)/

	install -d $(DESTDIR)$(sharedir)/piuparts
	install -m 0755 piuparts-slave piuparts-master piuparts-report piuparts-analyze $(DESTDIR)$(sharedir)/piuparts/

	install -d $(DESTDIR)$(site26)/piupartslib
	install -d $(DESTDIR)$(site27)/piupartslib
	install -m 0644 piupartslib/*.py $(DESTDIR)$(site26)/piupartslib/
	install -m 0644 piupartslib/*.py $(DESTDIR)$(site27)/piupartslib/

	install -d $(DESTDIR)$(sharedir)/piuparts/lib
	install -m 0644 lib/*.sh $(DESTDIR)$(sharedir)/piuparts/lib/

	install -d $(DESTDIR)$(sharedir)/piuparts/master
	install -m 0755 $(filter-out %.in,$(wildcard master-bin/*)) $(DESTDIR)$(sharedir)/piuparts/master/

	install -d $(DESTDIR)$(sharedir)/piuparts/master/known_problems
	install -m 0644 known_problems/*.conf $(DESTDIR)$(sharedir)/piuparts/master/known_problems/

	install -d $(DESTDIR)$(sharedir)/piuparts/slave
	install -m 0755 $(filter-out %.in,$(wildcard slave-bin/*)) $(DESTDIR)$(sharedir)/piuparts/slave/

	install -d $(DESTDIR)$(htdocsdir)
	install -m 0644 htdocs/*.* $(DESTDIR)$(htdocsdir)/

	install -d $(DESTDIR)$(htdocsdir)/images
	install -m 0644 htdocs/images/*.* $(DESTDIR)$(htdocsdir)/images/
	ln -sf /usr/share/icons/Tango/24x24/status/sunny.png $(DESTDIR)$(htdocsdir)/images/sunny.png
	ln -sf /usr/share/icons/Tango/24x24/status/weather-severe-alert.png $(DESTDIR)$(htdocsdir)/images/weather-severe-alert.png

	install -d $(DESTDIR)$(htdocsdir)/templates/mail
	install -m 0644 bug-templates/*.mail $(DESTDIR)$(htdocsdir)/templates/mail/

	install -d $(DESTDIR)$(etcdir)/piuparts
	@set -e -x ; \
	for d in $$(ls custom-scripts) ; do \
		install -d $(DESTDIR)$(etcdir)/piuparts/$$d ; \
		install -m 0755 custom-scripts/$$d/* $(DESTDIR)$(etcdir)/piuparts/$$d/ ; done

	#install -d $(DESTDIR)$(etcdir)/piuparts/known_problems
	#install -m 0644 known_problems/*.conf $(DESTDIR)$(etcdir)/piuparts/known_problems/


check:
	python piuparts.py unittest
	python unittests.py

clean:
	rm -f piuparts piuparts-slave piuparts-master piuparts-report piuparts-analyze
	rm -f piuparts.1 piuparts.1.xml piuparts.1.html README.xml README.html docbook-xsl.css piuparts.html
	rm -f *.pyc piupartslib/*.pyc
	rm -f $(SCRIPTS_GENERATED)
