path = 'snippet.flac';
% Specifies how many octaves we search through when deciding whether a
% given frequency is being masked by another frequency.
octave_analysis_range = 1;
softer_factor_threshold = 8;
% The further apart an amplitude spike is from other frequencies, the less 
% likely it is to drown out said frequency. This variable specifies how 
% much 'softer' said frequency's amplitude has to be to be considered 
% masked by the other frequency by this equation:
% Drowned out = softness * (wavelength_distance_weighting * (1 + wavelength_distance_factor)) >
% softer_factor_threshold
wavelength_distance_weighting = 2;
% How much of the audio we are analysing, in milliseconds, at any given
% amount of time
window_time_width = 4;
[o_y, o_fs] = audioread(path);
plot(fftshift(fft(o_y(:, 1))));
audio_info = audioinfo(path);
disp(audio_info);

% Number of elements per window
window_sample_width = round(audio_info.SampleRate * (window_time_width / 1000)); 
audio_sample_len = size(o_y, 1);
w = 1;
channel_len = size(o_y, 2);
total_components_removed = 0;
total_windows = 0;
% This loop analyses audio in intervals of <window_sample_width> samples
% and removes all frequencies that are considered to be masked by other
% frequencies.
while w <= audio_sample_len
    end_window_index = min(w + (window_sample_width - 1), audio_sample_len);
    for c = 1:channel_len
        % Grab the fast fourier transform so that we can determine what 
        % frequencies are being overpowered by other frequencies in the sample
        fft_y = fft(o_y(w:end_window_index, c));
        fft_y_len = size(fft_y, 1);
        % Abs the FFT so we can look at soley the amplitude of the frequencies.
        % The FFT, otherwise, would be covered in complex numbers.
        fft_y_abs = abs(fft_y);
        f = 1;
        while f <= fft_y_len
            amplitude = fft_y_abs(f);
            if amplitude ~= 0
                other_f = max(1, ceil(octave_frequency(-octave_analysis_range, f)));
                other_f_end_index = min(floor(octave_frequency(octave_analysis_range, f)), fft_y_len);
                % The maximum amount of 'softness' out of all the frequencies 
                % that we compared the frequency we're look at with.
                max_softer_factor = 0;
                wavelength = 1/f;
                while other_f <= other_f_end_index
                    other_wavelength=  1/other_f;
                    % How disimilar a two wavelengths are to each other in.
                    percent_wavelength_disimilarity = abs(wavelength - other_wavelength) / min(wavelength, other_wavelength);
                    other_amplitude = fft_y_abs(other_f);
                    softness = other_amplitude/amplitude;
                    % How soft the analysed frequency is to the other
                    % frequency.
                    relative_softness = softness * ((1-percent_wavelength_disimilarity) ^ (wavelength_distance_weighting));
                    max_softer_factor = max(relative_softness, max_softer_factor);
                    other_f = other_f + 1;
                end
                if max_softer_factor >= softer_factor_threshold
                    fft_y(f) = 0;
                    total_components_removed = total_components_removed + 1;
                end
            end
            f = f + 1;
        end
        % disp(total_windows);
        n_y = ifft(fft_y, 'symmetric');
        for i = 1:fft_y_len            
            o_y(w + (i - 1), c) = n_y(i);
        end
        % Add 1 window per channel
        total_windows = total_windows + 1;
    end
    % Ideally we would slide over the samples but that would take too long,
    % instead, increase the window starting position by half of the window
    % width.
    w = w + floor(window_sample_width / 2);
end
average_components_removed_per_window = total_components_removed / total_windows;
plot(abs(fftshift(fft(o_y(:,1)))));
sound(o_y, o_fs);
audiowrite('snippet-output.flac', o_y, o_fs, 'BitsPerSample', audio_info.BitsPerSample);
function o = octave_frequency(octaves, original_frequency)
    o = (2 ^ octaves) * original_frequency;
end