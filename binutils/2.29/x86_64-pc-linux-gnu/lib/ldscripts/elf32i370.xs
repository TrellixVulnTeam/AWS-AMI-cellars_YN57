/* Script for ld --shared: link shared library */
/* Copyright (C) 2014-2017 Free Software Foundation, Inc.
   Copying and distribution of this script, with or without modification,
   are permitted in any medium without royalty provided the copyright
   notice and this notice are preserved.  */
OUTPUT_FORMAT("elf32-i370", "elf32-i370",
	      "elf32-i370")
OUTPUT_ARCH(i370)
ENTRY(_start)
/* Do we need any of these for elf?
   __DYNAMIC = 0;    */
PROVIDE (__stack = 0);
SECTIONS
{
  /* Read-only sections, merged into text segment: */
  . = SIZEOF_HEADERS;
  .hash		  : { *(.hash)		}
  .dynsym	  : { *(.dynsym)		}
  .dynstr	  : { *(.dynstr)		}
  .gnu.version   : { *(.gnu.version)      }
  .gnu.version_d   : { *(.gnu.version_d)  }
  .gnu.version_r   : { *(.gnu.version_r)  }
  .rela.text     :
    { *(.rela.text) *(.rela.gnu.linkonce.t*) }
  .rela.data     :
    { *(.rela.data) *(.rela.gnu.linkonce.d*) }
  .rela.rodata   :
    { *(.rela.rodata) *(.rela.gnu.linkonce.r*) }
  .rela.got	  : { *(.rela.got)	}
  .rela.got1	  : { *(.rela.got1)	}
  .rela.got2	  : { *(.rela.got2)	}
  .rela.ctors	  : { *(.rela.ctors)	}
  .rela.dtors	  : { *(.rela.dtors)	}
  .rela.init	  : { *(.rela.init)	}
  .rela.fini	  : { *(.rela.fini)	}
  .rela.bss	  : { *(.rela.bss)	}
  .rela.plt	  : { *(.rela.plt)	}
  .rela.sdata	  : { *(.rela.sdata)	}
  .rela.sbss	  : { *(.rela.sbss)	}
  .rela.sdata2	  : { *(.rela.sdata2)	}
  .rela.sbss2	  : { *(.rela.sbss2)	}
  .text      :
  {
    *(.text)
    /* .gnu.warning sections are handled specially by elf32.em.  */
    *(.gnu.warning)
    *(.gnu.linkonce.t*)
  } =0
  .init		  : { *(.init)		} =0
  .fini		  : { *(.fini)		} =0
  .rodata	  : { *(.rodata) *(.gnu.linkonce.r*) }
  .rodata1	  : { *(.rodata1) }
  _etext = .;
  PROVIDE (etext = .);
  /* Adjust the address for the data segment.  We want to adjust up to
     the same address within the page on the next page up.  It would
     be more correct to do this:
       . = ALIGN(CONSTANT (MAXPAGESIZE)) + (ALIGN(8) & (CONSTANT (MAXPAGESIZE) - 1));
     The current expression does not correctly handle the case of a
     text segment ending precisely at the end of a page; it causes the
     data segment to skip a page.  The above expression does not have
     this problem, but it will currently (2/95) cause BFD to allocate
     a single segment, combining both text and data, for this case.
     This will prevent the text segment from being shared among
     multiple executions of the program; I think that is more
     important than losing a page of the virtual address space (note
     that no actual memory is lost; the page which is skipped can not
     be referenced).  */
  . =  ALIGN(8) + CONSTANT (MAXPAGESIZE);
  .data    :
  {
    *(.data)
    *(.gnu.linkonce.d*)
    CONSTRUCTORS
  }
  .data1   : { *(.data1) }
  .got1		  : { *(.got1) }
  .dynamic	  : { *(.dynamic) }
  /* Put .ctors and .dtors next to the .got2 section, so that the pointers
     get relocated with -mrelocatable. Also put in the .fixup pointers.
     The current compiler no longer needs this, but keep it around for 2.7.2  */
		PROVIDE (_GOT2_START_ = .);
  .got2		  :  { *(.got2) }
		PROVIDE (__CTOR_LIST__ = .);
  .ctors	  : { *(.ctors) }
		PROVIDE (__CTOR_END__ = .);
		PROVIDE (__DTOR_LIST__ = .);
  .dtors	  : { *(.dtors) }
		PROVIDE (__DTOR_END__ = .);
		PROVIDE (_FIXUP_START_ = .);
  .fixup	  : { *(.fixup) }
		PROVIDE (_FIXUP_END_ = .);
		PROVIDE (_GOT2_END_ = .);
		PROVIDE (_GOT_START_ = .);
  .got		  : { *(.got) }
  .got.plt	  : { *(.got.plt) }
  .sdata2   : { *(.sdata2) }
  .sbss2   : { *(.sbss2) }
		PROVIDE (_GOT_END_ = .);
  /* We want the small data sections together, so single-instruction offsets
     can access them all, and initialized data all before uninitialized, so
     we can shorten the on-disk segment size.  */
  .sdata	  : { *(.sdata) }
  _edata  =  .;
  PROVIDE (edata = .);
  .sbss      :
  {
    PROVIDE (__sbss_start = .);
    *(.sbss)
    *(.scommon)
    *(.dynsbss)
    PROVIDE (__sbss_end = .);
  }
  .plt   : { *(.plt) }
  .bss       :
  {
   PROVIDE (__bss_start = .);
   *(.dynbss)
   *(.bss)
   *(COMMON)
  }
  _end = . ;
  PROVIDE (end = .);
  /* These are needed for ELF backends which have not yet been
     converted to the new style linker.  */
  .stab 0 : { *(.stab) }
  .stabstr 0 : { *(.stabstr) }
  /* DWARF debug sections.
     Symbols in the DWARF debugging sections are relative to the beginning
     of the section so we begin them at 0.  */
  /* DWARF 1 */
  .debug          0 : { *(.debug) }
  .line           0 : { *(.line) }
  /* GNU DWARF 1 extensions */
  .debug_srcinfo  0 : { *(.debug_srcinfo) }
  .debug_sfnames  0 : { *(.debug_sfnames) }
  /* DWARF 1.1 and DWARF 2 */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_pubnames 0 : { *(.debug_pubnames) }
  /* DWARF 2 */
  .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end ) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_macinfo  0 : { *(.debug_macinfo) }
  /* SGI/MIPS DWARF 2 extensions */
  .debug_weaknames 0 : { *(.debug_weaknames) }
  .debug_funcnames 0 : { *(.debug_funcnames) }
  .debug_typenames 0 : { *(.debug_typenames) }
  .debug_varnames  0 : { *(.debug_varnames) }
  /* DWARF 3 */
  .debug_pubtypes 0 : { *(.debug_pubtypes) }
  .debug_ranges   0 : { *(.debug_ranges) }
  /* DWARF Extension.  */
  .debug_macro    0 : { *(.debug_macro) }
  .debug_addr     0 : { *(.debug_addr) }
  .gnu.attributes 0 : { KEEP (*(.gnu.attributes)) }
}
