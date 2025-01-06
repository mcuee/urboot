# How to select a bootloader

It is tempting to go for the most feature-rich bootloader that
there is. However, consider carefully what you need:
 - **`pgm_write_page(sram, flash)`** for the application at `FLASHEND-4+1` is a necessary feature
   for applications that want to use MCU flash beyond the code as storage in a similar fashion to
   EEPROM. It has security implications, but no more than generally having a bootloader on the
   chip.
 - **EPROM** access is generally thought of as useful. Applications can read initialisation
   parameters from EEPROM and store results there in the safe knowledge that the bootloader gives
   independent access to EEPROM via `avrdude` calls.
 - **Dual boot.** If there is no plan for over-the-air programming, and no external SPI flash on
   your board either, there is little benefit of using a dual-boot bootloader. Whilst they deal
   gracefully with a board that has no external SPI flash memory, they will add a little delay at
   each external reset or WDT reset. Also they toggle the SPI and chip select lines at each reset,
   which is something that not all projects can handle.
 - **Vector bootloaders or not**. This question only arises on parts that have hardware support,
   otherwise it has got to be a vector bootloader. In general, modern AVR parts with a universal
   programming and debug interface would not use (or implement) vector bootloaders. Other than that
   vector bootloaders normally occupy a multiple of the device's flash memory page size. In
   contrast to this, hardware-supported bootloaders often have very large sizes, eg, the ATmega328p
   can have hw-supported bootloaders with 512, 1024, 2048 and 4096 bytes size. Its flash page size
   is 128 bytes, so vector bootloaders can occupy any multiple of that.<p>Normally, the best use of
   MCU flash space is to select `j`-type vector bootloaders (see below), and only select `h`-type
   hardware supported bootloaders if they happen to occupy the same space. If, however, the
   bootloader is used for firmware updates on products where the MCU is not accessible otherwise,
   vector bootloaders have the disadvantage that they can brick in very rare cases, eg, if
   interrupted during upload at a sensitive spot, eg, by Vcc dipping just below the brownout
   detection whilst the MCU uses slightly more power during flash write of the first page that
   contains the reset vector.<p> Either way, when installing bootloaders take care to program the
   right fuses (see *Usage* in
   [readme](https://github.com/stefanrueger/urboot/blob/main/README.md)). There are three types of
   vector bootloaders that the urboot project offers:
    + `j` versions cost minimal to no extra space in the bootloader and need applications to be
      patched during upload. `avrdude -c urclock` does that auto-magically.
    + In `v` and `V` versions the bootloader patches the applications itself to various degrees of
      rigour. They generally consume a lot of extra space on the MCU at no run-time benefit; these
      types are not recommended, and urboot support for these have been withdrawn from version `u8.0`.
 - **Protection** from overwriting itself and protection of the reset vector in vector bootloaders.
   All urboot bootloaders are protected from overwriting themselves, and this protection can no
   longer be switched off at compile time even when using hardware-supported bootloaders that could
   in theory also be protected by lock bits (as the user may have chosen not to program the lock
   bits). Vector bootloaders have an Achilles' heel in that the reset vector needs to always point
   to the bootloader. It is recommended the bootloader be compiled with `-DPROTECTRESET=1` or, if
   using `make` to supply `PROTECTRESET=1` on the make command line. If there is code space left
   then `urboot.c` automatically switches on this protection. Vector bootloaders with reset vector
   protection show a captial `P` in their features (hardware bootloaders don't need that). Not all
   is lost if the reset vector is unprotected in the bootloader: the `-c urclock` bootloader does
   not normally allow the reset vector to be overwritten during upload, and the `-c urclock -t`
   terminal also protects the reset vector of vector bootloaders. Self-modifying applications
   calling `pgm_write_page(sram, 0)` to write to the vector table can overwrite the reset vector,
   though, unless the bootloader has reset vector protection. If that happens, the bootloader needs
   to be re-flashed.
 - **Autobaud.** If you have a fixed workflow where you can control the host baud rate, then the
   extra 16 bytes for autobaud detection may not be worth your while: vector bootloaders have to
   have a size of a multiple of the memory page size. If, by reducing the features of the
   bootloader, one can save a memory page for the bootloader that memory page is then available for
   *every* application that you may want to upload.
 - **Chip erase** in the bootloader makes programming faster on MCUs with large flash. If the
   bootloader does not offer chip erase `avrdude -c urclock` erases flash during upload of a new
   application by filling unused flash with 0xff; the extra time needed for programming without the
   chip erase feature is hardly noticeable on devices with up to 8k flash. As an aside, optiboot
   *pretends* it erases flash but does *nothing*, which means that programming with `avrdude -c
   arduino` and optiboot bootloaders can leave code from a previous session in flash, which is
   considered a security problem. In contrast, `avrdude -c urclock` and urboot bootloader always
   scrub flash whether the faster *chip erase* feature was compiled in or not.
 - **Update flash** as opposed to write is a useful feature to counter wear of flash by only
   writing to flash if the desired contents is not already there. Very useful for projects that use
   extensively the bootloader-provided `pgm_write_page(sram, flash)` routine in application space.
   Generally, `UPDATE_FL=1` is sufficient, though, if there is still space in the bootloader, why
   not go full monty with `UPDATE_FL=4`. The last level `4` has diminishing returns in terms of
   wearing flash out less but that will be the fastest urboot implementation there is.
 - **LED** flashing during upload/download costs six additional code bytes. The novelty of
   exercising a LED during upload/download wears quickly off, and projects can not normally
   re-purpose the LED line unless they accept it being toggled as output during external reset.
 - **[Template](https://github.com/stefanrueger/urboot/blob/main/docs/makeoptions.md#template_sfm)
   bootloaders.** Pre-compiled bootloaders labelled `_lednop` or `_template` contain nops as
   placeholders so that just before flashing them, another program can replace the nops with code
   to pluck the right LED line and/or CS line needed for dual boot. They normally occupy the same
   space as bootloaders that are compiled for a specific LED and/or CS line, but can be slightly
   bigger than those with known LED/CS lines, particularly when these are known to sit on the same
   port.
 - **Frills.** These are features that are not necessary for the working of the bootloader, for
   example that the application is started sooner after upload, or that frame errors in the serial
   communication get the bootloader to exit quickly. It is OK not to have these frills, particlarly
   when it means an extra memory page for *every* application. The `AUTOFRILLS=`*list* make option is
   designed to find the highest `FRILLS` level that fits into the space that is occupied by the first
   FRILLS level in the *list*. This way the bootloader makes use of remaining space for frills.
 - Urboot u7.7 and earlier had a choice of **protocol `u` or `s`.** Bootloaders with the `s` bit
   implemented a skeleton STK500 protocol; they could normally also be programmed using `avrdude
   -c arduino`; the `s` protocol did *not* increase functionality but costed *a lot* of bootloader
   code space; they were only recommended when no version of avrdude with `-c urclock` programmer
   was available. As recent avrdude versions with the necessary urclock programmer are now
   reasonably widely distributed, urboot u8.0 and above no longer offer the `s` protocol.
