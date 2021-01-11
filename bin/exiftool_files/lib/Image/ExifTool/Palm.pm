#------------------------------------------------------------------------------
# File:         Palm.pm
#
# Description:  Read Palm Database files
#
# Revisions:    2014/05/28 - P. Harvey Created
#
# References: 1) http://wiki.mobileread.com/wiki/PDB
#             2) http://wiki.mobileread.com/wiki/MOBI
#------------------------------------------------------------------------------

package Image::ExifTool::Palm;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessEXTH($$$);

# type/creator ID's for Palm database files
my %palmTypes = (
    '.pdfADBE' => 'Adobe Reader',
    'TEXtREAd' => 'PalmDOC',
    'BVokBDIC' => 'BDicty',
    'DB99DBOS' => 'DB (Database program)',
    'PNRdPPrs' => 'eReader',
    'DataPPrs' => 'eReader',
    'vIMGView' => 'FireViewer (ImageViewer)',
    'PmDBPmDB' => 'HanDBase',
    'InfoINDB' => 'InfoView',
    'ToGoToGo' => 'iSilo',
    'SDocSilX' => 'iSilo 3',
    'JbDbJBas' => 'JFile',
    'JfDbJFil' => 'JFile Pro',
    'DATALSdb' => 'LIST',
    'Mdb1Mdb1' => 'MobileDB',
    'BOOKMOBI' => 'Mobipocket',
    'DataPlkr' => 'Plucker',
    'DataSprd' => 'QuickSheet',
    'SM01SMem' => 'SuperMemo',
    'TEXtTlDc' => 'TealDoc',
    'InfoTlIf' => 'TealInfo',
    'DataTlMl' => 'TealMeal',
    'DataTlPt' => 'TealPaint',
    'dataTDBP' => 'ThinkDB',
    'TdatTide' => 'Tides',
    'ToRaTRPW' => 'TomeRaider',
    'zTXTGPlm' => 'Weasel',
    'BDOCWrdS' => 'WordSmith',
);

my %dateTimeInfo = (
    # like QuickTime, the time zero should be Jan 1, 1904, but not all software writes this,
    # so assume a time zero of Jan 1, 1970 if the date is before this
    RawConv => q{
        my $offset = (66 * 365 + 17) * 24 * 3600;
        return $val - $offset if $val >= $offset;
        return $val;
    },
    ValueConv => 'ConvertUnixTime($val, 1)', # (UTC written by "EPUB Converter", ref PH)
    PrintConv => '$self->ConvertDateTime($val)',
);

# Palm Database header information
%Image::ExifTool::Palm::Main = (
    GROUPS => { 0 => 'Palm', 1 => 'Palm', 2 => 'Document' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32u',
    NOTES => q{
        Information extracted from Palm database files (PDB and PRC extensions),
        Mobipocket electronic books (MOBI), and Amazon Kindle KF7 and KF8 books (AZW
        and AZW3).
    },
    0 => { Name => 'DatabaseName', Format => 'string[32]' },
    # 8 - int16u: file attributes (not very useful)
    # 8.5 - int16u: version
    9 => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        %dateTimeInfo,
    },
    10 => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        %dateTimeInfo,
    },
    11 => {
        Name => 'LastBackupDate',
        Groups => { 2 => 'Time' },
        %dateTimeInfo,
    },
    12 => 'ModificationNumber',
    15 => {
        Name => 'PalmFileType',
        Format => 'undef[8]',
        PrintConv => \%palmTypes,
    },
);


# MOBI header tags
%Image::ExifTool::Palm::MOBI = (
    GROUPS => { 0 => 'Palm', 1 => 'MOBI', 2 => 'Document' },
    NOTES => q{
        Information extracted from the MOBI header of Mobipocket and Amazon Kindle
        KF7 and KF8 files.
    },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32u',
    0 => {
        Name => 'Compression',
        Format => 'int16u',
        PrintConv => {
            1 => 'None',
            2 => 'PalmDOC',
            17480 => 'HUFF/CDIC',
        },
    },
    1  => {
        Name => 'UncompressedTextLength',
        PrintConv => \&Image::ExifTool::ConvertFileSize,
    },
    3 => {
        Name => 'Encryption',
        PrintConv => {
            0 => 'None',
            1 => 'Old Mobipocket',
            2 => 'Mobipocket',
        },
    },
    6 => {
        Name => 'MobiType',
        PrintConv => {
            2 => 'Mobipocket Book',
            3 => 'PalmDoc Book',
            4 => 'Audio',
            232 => 'mobipocket? generated by kindlegen1.2',
            248 => 'KF8: generated by kindlegen2',
            257 => 'News',
            258 => 'News_Feed',
            259 => 'News_Magazine',
            513 => 'PICS',
            514 => 'WORD',
            515 => 'XLS',
            516 => 'PPT',
            517 => 'TEXT',
            518 => 'HTML',
        },
    },
    7 => {
        Name => 'CodePage',
        RawConv => '$$self{CodePage} = $val',
        PrintConv => {
            # just define commonly used code pages
            # (a much more complete list may be found in FlashPix.pm)
            1252 => 'Windows Latin 1 (Western European)',
            65001 => 'Unicode (UTF-8)',
        },
    },
    9 => 'MobiVersion',
    21 => 'BookName',   # this is actually an offset, but replace it with the string later
    26 => 'MinimumVersion',
);

# MOBI extended header tags
%Image::ExifTool::Palm::EXTH = (
    GROUPS => { 0 => 'Palm', 1 => 'MOBI', 2 => 'Document' },
    FORMAT => 'string',
    NOTES => 'Information extracted from the MOBI extended header.',
    PROCESS_PROC => \&ProcessEXTH,
    1 => 'DRMServerID',
    2 => 'DRMCommerceID',
    3 => 'DRM_E-BookBaseID',
    100 => { Name => 'Author', Groups => { 2 => 'Author' } },
    101 => 'Publisher',
    102 => 'Imprint',
    103 => 'Description',
    104 => 'ISBN',
    105 => { Name => 'Subject', List => 1 },
    106 => {
        Name => 'PublishDate',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            require Image::ExifTool::XMP;
            Image::ExifTool::XMP::ConvertXMPDate($val, 1);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    107 => 'Review',
    108 => 'Contributor',
    109 => { Name => 'Rights', Groups => { 2 => 'Author' } },
    110 => 'SubjectCode',
    111 => 'BookType',
    112 => 'Source',
    113 => 'ASIN',
    114 => 'BookVersion',
    115 => { Name => 'SampleFlag',   Format => 'int32u' },
    116 => { Name => 'StartReading', Format => 'int32u' },
    117 => 'Adult',
    118 => 'RetailPrice',
    119 => 'RetailPriceCurrency',
    # 121 => 'KF8BoundaryOffset',
    125 => { Name => 'ResourceCount', Format => 'int32u' },
    129 => 'KF8CoverURI',
    200 => 'DictionaryShortName',
    # 201 => { Name => 'CoverOffset', Format => 'int32u' },
    # 202 => { Name => 'ThumbOffset', Format => 'int32u' },
    # 203 => 'HasFakeCover',
    204 => {
        Name => 'CreatorSoftware',
        Format => 'int32u',
        PrintConv => {
            1 => 'Mobigen',
            2 => 'Mobipocket',
            200 => 'Kindlegen (Windows)',
            201 => 'Kindlegen (Linux)',
            202 => 'Kindlegen (Mac)',
        },
    },
    205 => { Name => 'CreatorMajorVersion', Format => 'int32u' },
    206 => { Name => 'CreatorMinorVersion', Format => 'int32u' },
    207 => { Name => 'CreatorBuildNumber',  Format => 'int32u' },
    208 => 'Watermark',
    209 => 'Tamper-proofKeys',
    # 300 => 'FontSignature',
    401 => { Name => 'ClippingLimit', Format => 'int8u' },
    402 => 'PublisherLimit',
    404 => {
        Name => 'TextToSpeech',
        Format => 'int8u',
        PrintConv => { 0 => 'Enabled', 1 => 'Disabled' },
    },
    405 => { Name => 'RentalFlag', Format => 'int8u' }, #?
    406 => 'RentalExpirationDate',
    501 => { Name => 'CDEType',    Format => 'int32u' },
    502 => 'LastUpdateTime',
    503 => 'UpdatedTitle',
    504 => 'ASIN2',
    524 => 'Language',
    525 => 'Alignment',
    535 => 'CreatorBuildNumber2',
);

#------------------------------------------------------------------------------
# Process the MOBI extended header
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 (EXTH should have already been validated)
sub ProcessEXTH($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $enc = $$dirInfo{Encoding} || 'UTF8';
    my $dirLen = length $$dataPt;
    my ($index, $pos);

    $et->VerboseDir('EXTH', $$dirInfo{NumEntries}, $dirLen);

    # process the EXTH entries
    for ($index=0, $pos=0; ; ++$index) {
        last if $pos + 8 > $dirLen;
        my $tag = Get32u($dataPt, $pos);
        my $len = Get32u($dataPt, $pos + 4);
        last if $len < 8 or $pos + $len > $dirLen;
        my $key = $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $pos + 8,
            Size    => $len - 8,
            Index   => $index,
        );
        # recode text if necessary
        $$et{VALUE}{$key} = $et->Decode($$et{VALUE}{$key}, $enc) if $key;
        $pos += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a Palm DB file
# Inputs: 0) ExifTool ref, 1) dirInfo reference
# Returns: 1 if this was a recognized PDB file, 0 otherwise
sub ProcessPDB($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $size, $enc);
    my $verbose = $et->Options('Verbose');

    # verify this is a valid Palm DB file
    return 0 unless $raf->Read($buff, 86) == 86;
    my $type = $palmTypes{substr($buff, 60, 8)};
    return 0 unless $type;
#
# Read and process the Palm DB file header
#
    $et->SetFileType($type eq 'Mobipocket' ? 'MOBI' : 'PDB');
    SetByteOrder('MM');

    my $tagTablePtr = GetTagTable('Image::ExifTool::Palm::Main');
    $et->ProcessDirectory({ DataPt => \$buff }, $tagTablePtr);

    return 1 unless $type eq 'Mobipocket' and Get16u(\$buff, 76);
#
# Read and process MOBI header (should be the first record)
#
    my $offset = Get32u(\$buff, 78);    # get offset to first record
    unless ($raf->Seek($offset, 0) and $raf->Read($buff, 274) == 274) {
        $et->Warn('Truncated MOBI header');
        return 1;
    }
    unless (substr($buff, 16, 4) eq 'MOBI') {
        $et->Warn('Invalid MOBI header');
        return 1;
    }
    $tagTablePtr = GetTagTable('Image::ExifTool::Palm::MOBI');
    $et->ProcessDirectory({ DataPt => \$buff }, $tagTablePtr);

    # get text encoding
    $enc = $Image::ExifTool::charsetName{"cp$$et{CodePage}"} if $$et{CodePage};
    $enc = 'UTF8' unless $enc;

    # extract the BookName string
    my $off = Get32u(\$buff, 84);
    my $len = Get32u(\$buff, 88);

    $raf->Seek($offset+$off, 0) and $raf->Read($buf2, $len) == $len or $buf2 = '<err>';
    $$et{VALUE}{BookName} = $et->Decode($buf2, $enc);
#
# Process the MOBI extended header if it exists
#
    # first, check the flag bit to see if the EXTH record should exist
    my $flag = Get32u(\$buff, 128);
    return 1 unless $flag & 0x40;   # check extended header flag

    $len = Get32u(\$buff, 20) + 16; # MOBI header length (including PalmDOC header)

    unless ($raf->Seek($offset+$len, 0) and $raf->Read($buf2, 12) == 12 and
        substr($buf2,0,4) eq 'EXTH' and ($size = Get32u(\$buf2, 4)) > 12)
    {
        $et->Warn('Invalid MOBI extended header');
        return 1;
    }

    # read and process the MOBI extended header
    $size -= 12;
    $raf->Read($buff, $size) == $size or $et->Warn('Truncated MOBI extended header'), return 1;
    my %dirInfo = (
        DataPt     => \$buff,
        DataPos    => $offset + $len + 12,
        NumEntries => Get32u(\$buf2, 8),
        Encoding   => $enc,
    );
    $tagTablePtr = GetTagTable('Image::ExifTool::Palm::EXTH');
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Palm - Read Palm Database files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains code to extract metadata from Palm database files (PDB
and PRC extensions), Mobipocket electronic books (MOBI), and Amazon Kindle
KF7 and KF8 books (AZW and AZW3).

=head1 AUTHOR

Copyright 2003-2021, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://wiki.mobileread.com/wiki/PDB>

=item L<http://wiki.mobileread.com/wiki/MOBI>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Palm Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

