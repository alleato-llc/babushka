import Foundation
import Testing
@testable import Babushka

@Suite("MKVIdentification JSON Parsing")
struct MKVIdentificationTests {

    static let sampleJSON = """
    {
      "attachments": [],
      "chapters": [],
      "container": {
        "properties": {
          "container_type": 17,
          "date_local": "2010-08-21T14:06:43-04:00",
          "date_utc": "2010-08-21T18:06:43Z",
          "duration": 46665000000,
          "is_providing_timestamps": true,
          "muxing_application": "libebml v1.0.0 + libmatroska v1.0.0",
          "segment_uid": "9d516a0f927a12d286e1502d23d0fdb0",
          "timestamp_scale": 1000000,
          "writing_application": "mkvmerge v4.0.0 ('The Stars were mine') built on Jun  6 2010 16:18:42"
        },
        "recognized": true,
        "supported": true,
        "type": "Matroska"
      },
      "errors": [],
      "file_name": "test5.mkv",
      "global_tags": [
        {
          "num_entries": 3
        }
      ],
      "identification_format_version": 20,
      "track_tags": [],
      "tracks": [
        {
          "codec": "AVC/H.264/MPEG-4p10",
          "id": 0,
          "properties": {
            "codec_id": "V_MPEG4/ISO/AVC",
            "codec_private_data": "014d401fffe10014274d401fa918080093600d418041adb0ad7bdf0101000428ce09c8",
            "codec_private_length": 35,
            "default_duration": 41666665,
            "default_track": true,
            "display_dimensions": "1024x576",
            "display_unit": 0,
            "enabled_track": true,
            "forced_track": false,
            "language": "und",
            "minimum_timestamp": 0,
            "num_index_entries": 46,
            "number": 1,
            "packetizer": "mpeg4_p10_video",
            "pixel_dimensions": "1024x576",
            "uid": 1258329745
          },
          "type": "video"
        },
        {
          "codec": "AAC",
          "id": 1,
          "properties": {
            "audio_channels": 2,
            "audio_sampling_frequency": 48000,
            "codec_id": "A_AAC",
            "codec_private_data": "1190",
            "codec_private_length": 2,
            "default_duration": 21333333,
            "default_track": true,
            "enabled_track": true,
            "forced_track": false,
            "language": "und",
            "minimum_timestamp": 12000000,
            "num_index_entries": 0,
            "number": 2,
            "uid": 3452711582
          },
          "type": "audio"
        },
        {
          "codec": "SubRip/SRT",
          "id": 2,
          "properties": {
            "codec_id": "S_TEXT/UTF8",
            "codec_private_length": 0,
            "default_track": true,
            "enabled_track": true,
            "encoding": "UTF-8",
            "forced_track": false,
            "language": "eng",
            "minimum_timestamp": 3549000000,
            "num_index_entries": 0,
            "number": 3,
            "text_subtitles": true,
            "uid": 368310685
          },
          "type": "subtitles"
        }
      ],
      "warnings": []
    }
    """

    @Test("Parse root identification structure")
    func parseRootStructure() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        #expect(identification.fileName == "test5.mkv")
        #expect(identification.identificationFormatVersion == 20)
        #expect(identification.errors.isEmpty)
        #expect(identification.warnings.isEmpty)
        #expect(identification.tracks.count == 3)
        #expect(identification.attachments.isEmpty)
        #expect(identification.globalTags.count == 1)
        #expect(identification.globalTags[0].numEntries == 3)
    }

    @Test("Parse container properties")
    func parseContainer() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        let container = identification.container
        #expect(container.recognized == true)
        #expect(container.supported == true)
        #expect(container.type == "Matroska")
        #expect(container.properties.containerType == 17)
        #expect(container.properties.duration == 46665000000)
        #expect(container.properties.muxingApplication == "libebml v1.0.0 + libmatroska v1.0.0")
        #expect(container.properties.segmentUid == "9d516a0f927a12d286e1502d23d0fdb0")
        #expect(container.properties.timestampScale == 1000000)
    }

    @Test("Parse video track")
    func parseVideoTrack() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        let video = identification.tracks[0]
        #expect(video.codec == "AVC/H.264/MPEG-4p10")
        #expect(video.id == 0)
        #expect(video.type == .video)
        #expect(video.properties.codecId == "V_MPEG4/ISO/AVC")
        #expect(video.properties.video.pixelDimensions == "1024x576")
        #expect(video.properties.video.displayDimensions == "1024x576")
        #expect(video.properties.flags.defaultTrack == true)
        #expect(video.properties.language == "und")
        #expect(video.properties.number == 1)
    }

    @Test("Parse audio track")
    func parseAudioTrack() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        let audio = identification.tracks[1]
        #expect(audio.codec == "AAC")
        #expect(audio.type == .audio)
        #expect(audio.properties.audio.audioChannels == 2)
        #expect(audio.properties.audio.audioSamplingFrequency == 48000)
        #expect(audio.properties.uid == 3452711582)
    }

    @Test("Parse subtitle track")
    func parseSubtitleTrack() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        let subtitle = identification.tracks[2]
        #expect(subtitle.codec == "SubRip/SRT")
        #expect(subtitle.type == .subtitles)
        #expect(subtitle.properties.encoding == "UTF-8")
        #expect(subtitle.properties.textSubtitles == true)
        #expect(subtitle.properties.language == "eng")
    }

    @Test("TrackType decodes unknown types gracefully")
    func unknownTrackType() throws {
        let json = """
        {
          "codec": "Something",
          "id": 99,
          "properties": {
            "codec_id": "X_UNKNOWN",
            "codec_private_length": 0,
            "default_track": false,
            "enabled_track": true,
            "forced_track": false,
            "language": "und",
            "num_index_entries": 0,
            "number": 99,
            "uid": 12345
          },
          "type": "buttons"
        }
        """
        let data = Data(json.utf8)
        let track = try JSONDecoder().decode(MKVTrack.self, from: data)
        #expect(track.type == .unknown)
    }

    @Test("Container formatted duration")
    func formattedDuration() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        let formatted = identification.container.properties.formattedDuration
        #expect(formatted == "0:46")
    }

    @Test("Track properties computed values")
    func trackComputedProperties() throws {
        let data = Data(Self.sampleJSON.utf8)
        let identification = try JSONDecoder().decode(MKVIdentification.self, from: data)

        let video = identification.tracks[0]
        let fps = video.properties.formattedDefaultDuration
        #expect(fps != nil)
        #expect(fps!.contains("24."))  // ~24fps

        let audio = identification.tracks[1]
        #expect(audio.properties.audio.channelDescription == "Stereo")
        #expect(audio.properties.audio.formattedSamplingFrequency == "48.0 kHz")
    }

    @Test("Parse new flag and pixel crop properties")
    func parseNewFlagAndCropProperties() throws {
        let json = """
        {
          "codec": "AVC/H.264/MPEG-4p10",
          "id": 0,
          "properties": {
            "codec_id": "V_MPEG4/ISO/AVC",
            "codec_private_length": 35,
            "default_track": true,
            "enabled_track": true,
            "forced_track": false,
            "flag_original": true,
            "flag_visual_impaired": false,
            "flag_commentary": true,
            "language": "und",
            "num_index_entries": 46,
            "number": 1,
            "pixel_dimensions": "1920x1080",
            "pixel_crop_top": 138,
            "pixel_crop_bottom": 138,
            "pixel_crop_left": 0,
            "pixel_crop_right": 0,
            "uid": 1258329745
          },
          "type": "video"
        }
        """
        let data = Data(json.utf8)
        let track = try JSONDecoder().decode(MKVTrack.self, from: data)
        #expect(track.properties.flags.flagOriginal == true)
        #expect(track.properties.flags.flagVisualImpaired == false)
        #expect(track.properties.flags.flagCommentary == true)
        #expect(track.properties.video.pixelCropTop == 138)
        #expect(track.properties.video.pixelCropBottom == 138)
        #expect(track.properties.video.pixelCropLeft == 0)
        #expect(track.properties.video.pixelCropRight == 0)
    }

    @Test("Pixel width and height computed properties")
    func pixelWidthHeightComputed() throws {
        let json = """
        {
          "codec": "AVC/H.264/MPEG-4p10",
          "id": 0,
          "properties": {
            "codec_id": "V_MPEG4/ISO/AVC",
            "codec_private_length": 35,
            "default_track": true,
            "enabled_track": true,
            "forced_track": false,
            "language": "und",
            "num_index_entries": 0,
            "number": 1,
            "pixel_dimensions": "1920x1080",
            "uid": 12345
          },
          "type": "video"
        }
        """
        let data = Data(json.utf8)
        let track = try JSONDecoder().decode(MKVTrack.self, from: data)
        #expect(track.properties.video.pixelWidth == 1920)
        #expect(track.properties.video.pixelHeight == 1080)
    }

    @Test("Pixel width/height nil when no pixel dimensions")
    func pixelWidthHeightNil() throws {
        let json = """
        {
          "codec": "AAC",
          "id": 1,
          "properties": {
            "codec_id": "A_AAC",
            "codec_private_length": 2,
            "default_track": true,
            "enabled_track": true,
            "forced_track": false,
            "language": "und",
            "num_index_entries": 0,
            "number": 1,
            "uid": 12345
          },
          "type": "audio"
        }
        """
        let data = Data(json.utf8)
        let track = try JSONDecoder().decode(MKVTrack.self, from: data)
        #expect(track.properties.video.pixelWidth == nil)
        #expect(track.properties.video.pixelHeight == nil)
    }

    @Test("Dynamic tag_* properties are captured")
    func dynamicTagProperties() throws {
        let json = """
        {
          "codec": "AAC",
          "id": 1,
          "properties": {
            "codec_id": "A_AAC",
            "codec_private_length": 2,
            "default_track": true,
            "enabled_track": true,
            "forced_track": false,
            "language": "eng",
            "num_index_entries": 0,
            "number": 1,
            "uid": 12345,
            "tag_artist": "Test Artist",
            "tag_title": "Test Title"
          },
          "type": "audio"
        }
        """
        let data = Data(json.utf8)
        let track = try JSONDecoder().decode(MKVTrack.self, from: data)
        #expect(track.properties.tags["tag_artist"] == "Test Artist")
        #expect(track.properties.tags["tag_title"] == "Test Title")
    }

    @Test("Round-trip encode/decode preserves all nested fields")
    func roundTripEncoding() throws {
        let json = """
        {
          "codec": "AVC/H.264/MPEG-4p10",
          "id": 0,
          "properties": {
            "codec_id": "V_MPEG4/ISO/AVC",
            "codec_private_length": 35,
            "default_duration": 41666665,
            "default_track": true,
            "enabled_track": true,
            "forced_track": false,
            "flag_original": true,
            "flag_visual_impaired": false,
            "flag_commentary": true,
            "language": "eng",
            "minimum_timestamp": 0,
            "num_index_entries": 46,
            "number": 1,
            "pixel_dimensions": "1920x1080",
            "display_dimensions": "1920x1080",
            "display_unit": 0,
            "pixel_crop_top": 138,
            "pixel_crop_bottom": 138,
            "pixel_crop_left": 0,
            "pixel_crop_right": 0,
            "stereo_mode": 0,
            "packetizer": "mpeg4_p10_video",
            "audio_channels": 2,
            "audio_sampling_frequency": 48000,
            "audio_bits_per_sample": 16,
            "uid": 1258329745,
            "tag_artist": "Test"
          },
          "type": "video"
        }
        """
        let original = try JSONDecoder().decode(MKVTrack.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MKVTrack.self, from: encoded)

        // Flags
        #expect(decoded.properties.flags.defaultTrack == true)
        #expect(decoded.properties.flags.enabledTrack == true)
        #expect(decoded.properties.flags.forcedTrack == false)
        #expect(decoded.properties.flags.flagOriginal == true)
        #expect(decoded.properties.flags.flagVisualImpaired == false)
        #expect(decoded.properties.flags.flagCommentary == true)

        // Video
        #expect(decoded.properties.video.pixelDimensions == "1920x1080")
        #expect(decoded.properties.video.displayDimensions == "1920x1080")
        #expect(decoded.properties.video.displayUnit == 0)
        #expect(decoded.properties.video.pixelCropTop == 138)
        #expect(decoded.properties.video.pixelCropBottom == 138)
        #expect(decoded.properties.video.pixelCropLeft == 0)
        #expect(decoded.properties.video.pixelCropRight == 0)
        #expect(decoded.properties.video.stereoMode == 0)
        #expect(decoded.properties.video.packetizer == "mpeg4_p10_video")

        // Audio
        #expect(decoded.properties.audio.audioChannels == 2)
        #expect(decoded.properties.audio.audioSamplingFrequency == 48000)
        #expect(decoded.properties.audio.audioBitsPerSample == 16)

        // Top-level
        #expect(decoded.properties.codecId == "V_MPEG4/ISO/AVC")
        #expect(decoded.properties.language == "eng")
        #expect(decoded.properties.uid == 1258329745)
        #expect(decoded.properties.tags["tag_artist"] == "Test")
    }
}
