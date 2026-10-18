{
    This file is part of Dev-C++
    Copyright (c) 2004 Bloodshed Software

    Dev-C++ is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Dev-C++ is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Dev-C++; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit Version;

interface

//path delimiter
const
  pd = DirectorySeparator; // from System; this unit has no uses clause

  // exe properties
  DEVCPP = 'Penguin cpp';
  // Penguin cpp's own version (semantic versioning); it continues Dev-C++ 6.3
  DEVCPP_VERSION = '0.1.0';

  // delimiters
  DEV_INTERNAL_OPEN = '$__DEV_INTERNAL_OPEN';

  // config file names
  DEV_DEFAULTCODE_FILE = 'defaultcode.ini';
  DEV_SHORTCUTS_FILE = 'shortcuts.ini';
  DEV_CLASSFOLDERS_FILE = 'classfolders.ini';
  DEV_CODEINS_FILE = 'codeinsertion.ini';
  DEV_WEBMIRRORS_FILE = 'webmirrors.ini';
  DEV_TOOLS_FILE = 'tools.ini';

  // make stuff
  DEV_MAKE_FILE = 'Makefile.win';

  // themes
  DEV_GNOME_THEME = 'Gnome';
  DEV_NEWLOOK_THEME = 'New Look';
  DEV_BLUE_THEME = 'Blue';
  DEV_INTERNAL_THEME = 'New Look';

  LANGUAGE_DIR = 'Lang' + pd;
  ICON_DIR = 'Icons' + pd;
  HELP_DIR = 'Help' + pd;
  TEMPLATE_DIR = 'Templates' + pd;
  THEME_DIR = 'Themes' + pd;
  PACKAGES_DIR = 'Packages' + pd;

  // file extensions
  LIB_EXT = '.a';
  OBJ_EXT = '.o';
  DLL_EXT = '.so'; // shared library
  EXE_EXT = ''; // Linux programs have no extension: main.cpp builds main
  DEV_EXT = '.dev';
  HTML_EXT = '.html';
  RTF_EXT = '.rtf';
  TEX_EXT = '.tex';
  INI_EXT = '.ini';
  TEMPLATE_EXT = '.template';
  SYNTAX_EXT = '.syntax';
  C_EXT = '.c';
  CPP_EXT = '.cpp';
  CC_EXT = '.cc';
  CXX_EXT = '.cxx';
  CP2_EXT = '.c++';
  CP_EXT = '.cp';
  H_EXT = '.h';
  HPP_EXT = '.hpp';
  RC_EXT = '.rc';
  RES_EXT = '.res';
  RH_EXT = '.rh';
  GCH_EXT = '.gch'; // precompiled header
  DEF_EXT = '.def'; // definitions file

  // program defaults: the system's GCC tools, found in the PATH. They are also
  // the names of the settings keys that hold each compiler set's programs.
  MAKE_PROGRAM = 'make';
  GCC_PROGRAM = 'gcc';
  GPP_PROGRAM = 'g++';
  GDB_PROGRAM = 'gdb';
  GDB32_PROGRAM = 'gdb';
  WINDRES_PROGRAM = 'windres'; // only a settings key: Linux has no resource compiler
  GPROF_PROGRAM = 'gprof';
//  CLEAN_PROGRAM = 'rm.exe'; // cannot use del, it doesn't have a quiet mode
//  CLEAN_PROGRAM = 'del /f /q';

  // File dialog filters
  FLT_ALLFILES = 'All files (*.*)|*.*|';
  FLT_TEXTS = 'Text files (*.txt)|*.txt';
  FLT_LIBRARIES = 'Libraries (*.lib;*.a)|*.lib;*.a';
  FLT_PROJECTS = 'Dev-C++ project (*.dev)|*.dev';
  FLT_HEADS = 'Header files (*.h;*.hpp;*.rh;*.hh)|*.h;*.hpp;*.rh;*.hh';
  FLT_CS = 'C source files (*.c)|*.c';
  FLT_CPPS = 'C++ source files (*.cpp;*.cc;*.cxx;*.c++;*.cp)|*.cpp;*.cc;*.cxx;*.c++;*.cp';
  FLT_RES = 'Resource scripts (*.rc)|*.rc';
  FLT_MSVCPROJECTS = 'MS Visual C++ projects (*.dsp)|*.dsp';
  FLT_CBPROJECTS = 'Code::Blocks projects (*.cbp)|*.cbp';

  // Custom synedit style properties
  cBP = 'Breakpoints';
  cErr = 'Error line';
  cABP = 'Active breakpoints';
  cGut = 'Gutter';
  cSel = 'Selected text';
  cFld = 'Folding lines';

  // GPROF commands and displays
  GPROF_CHECKFILE = 'gmon.out';
  GPROF_CMD_GENFLAT = '-p';
  GPROF_CMD_GENMAP = '-q';

  // Deletes the files of "make clean". Dev-C++ ran the IDE itself with
  // INTERNAL_DEL (Windows has no rm).
  CLEAN_PROGRAM = 'rm -f';

implementation

end.

