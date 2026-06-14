import ketai.sensors.*;
import android.app.Activity;

// ============================================================
// SENSOR OBJECTS
// ============================================================
KetaiSensor sensor;

// ============================================================
// APP STATE
// ============================================================
enum AppState { READY, TRIAL, COMPLETE }
AppState appState = AppState.READY;

// ============================================================
// TRIAL STATE
// ============================================================
int currentTrial = 0;
final int TOTAL_TRIALS = 6;

// ============================================================
// SELECTION STATE
// ============================================================
final int NUM_OPTIONS = 4;
int currentPosition = 0;
int targetOption = -1;
int targetAction = 0;  // 0 = UP, 1 = DOWN (like professor's code)

// Clap detection
float soundLevel = 0.0;
float prevSoundLevel = 0.0;
final float CLAP_SPIKE_THRESHOLD = 600.0;
long lastClapTime = 0;
final int CLAP_DEBOUNCE_MS = 300;

// Accelerometer confirmation (UP/DOWN like scaffold)
final float Z_ACCEL_THRESHOLD = 4.0;  // Like scaffold: abs(z - 9.8) > 4
long countDownTimerWait = 0;  // Debounce like scaffold

// Timing - LIKE PROFESSOR'S CODE
long startTime = 0;    // When first trial starts
long finishTime = 0;   // When all trials complete

// Animation
float pulseAlpha = 0;
float pulseDirection = 1;

// ============================================================
// ANDROID AUDIO
// ============================================================
import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.media.AudioRecord;
import android.media.AudioFormat;
import android.media.MediaRecorder;

AudioRecord audioRecord;
Thread audioThread;
boolean isRecording = false;

final int SAMPLE_RATE = 44100;
final int CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO;
final int AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;
int bufferSize;

Activity activity;
boolean audioInitialized = false;

// ============================================================
// SETUP
// ============================================================
void setup() {
  fullScreen();
  orientation(PORTRAIT);
  textAlign(CENTER, CENTER);
  
  activity = this.getActivity();
  requestAudioPermission();
  
  sensor = new KetaiSensor(this);
  sensor.start();
  
  // Initialize random seed
  randomSeed(millis());
}

void requestAudioPermission() {
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) 
        != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(activity, 
        new String[]{Manifest.permission.RECORD_AUDIO}, 
        200);
    } else {
      initAudio();
    }
  } else {
    initAudio();
  }
}

void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
  if (requestCode == 200) {
    if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
      initAudio();
    }
  }
}

void initAudio() {
  bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT);
  
  if (ActivityCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) 
      != PackageManager.PERMISSION_GRANTED) {
    return;
  }
  
  audioRecord = new AudioRecord(
    MediaRecorder.AudioSource.MIC,
    SAMPLE_RATE,
    CHANNEL_CONFIG,
    AUDIO_FORMAT,
    bufferSize
  );
  
  audioInitialized = true;
  startAudioRecording();
}

void startAudioRecording() {
  if (!audioInitialized || isRecording) return;
  
  isRecording = true;
  audioRecord.startRecording();
  
  audioThread = new Thread(new Runnable() {
    public void run() {
      short[] buffer = new short[bufferSize];
      
      while (isRecording) {
        int readResult = audioRecord.read(buffer, 0, bufferSize);
        
        if (readResult > 0) {
          float sum = 0;
          for (int i = 0; i < readResult; i++) {
            sum += Math.abs(buffer[i]);
          }
          prevSoundLevel = soundLevel;
          soundLevel = sum / readResult;
          
          float spike = soundLevel - prevSoundLevel;
          
          if (spike > CLAP_SPIKE_THRESHOLD) {
            long now = millis();
            if (now - lastClapTime > CLAP_DEBOUNCE_MS) {
              lastClapTime = now;
              onClapDetected();
            }
          }
        }
      }
    }
  });
  
  audioThread.start();
}

void stopAudioRecording() {
  if (!isRecording) return;
  isRecording = false;
  if (audioRecord != null) {
    audioRecord.stop();
  }
}

// ============================================================
// DRAW LOOP
// ============================================================
void draw() {
  background(250);
  
  // Start timer on first trial
  if (startTime == 0 && appState == AppState.TRIAL) {
    startTime = millis();
  }
  
  // Countdown timer (like scaffold)
  countDownTimerWait--;
  
  // Animate pulse for green border
  pulseAlpha += pulseDirection * 3;
  if (pulseAlpha > 100 || pulseAlpha < 0) {
    pulseDirection *= -1;
  }
  
  switch (appState) {
    case READY:
      drawReady();
      break;
    case TRIAL:
      drawUI();
      break;
    case COMPLETE:
      drawCompletion();
      break;
  }
}

// ============================================================
// READY SCREEN WITH START BUTTON
// ============================================================
void drawReady() {
  fill(0);
  textSize(56);
  text("Ready?", width/2, height/3 - 20);
  
  fill(100);
  textSize(26);
  text("Clap to navigate", width/2, height/3 + 60);
  text("Phone UP or DOWN to select", width/2, height/3 + 100);
  
  // Start button
  int buttonW = 350;
  int buttonH = 90;
  int buttonX = width/2 - buttonW/2;
  int buttonY = height/2 + 120;
  
  if (mousePressed && mouseX > buttonX && mouseX < buttonX + buttonW &&
      mouseY > buttonY && mouseY < buttonY + buttonH) {
    fill(30);
  } else {
    fill(0);
  }
  
  noStroke();
  rect(buttonX, buttonY, buttonW, buttonH, 45);
  
  fill(255);
  textSize(32);
  text("Start", width/2, buttonY + buttonH/2 + 5);
}

void mouseReleased() {
  if (appState == AppState.READY) {
    int buttonW = 350;
    int buttonH = 90;
    int buttonX = width/2 - buttonW/2;
    int buttonY = height/2 + 120;
    
    if (mouseX > buttonX && mouseX < buttonX + buttonW &&
        mouseY > buttonY && mouseY < buttonY + buttonH) {
      startTrial();
      appState = AppState.TRIAL;
    }
  }
}

// ============================================================
// TRIAL MANAGEMENT
// ============================================================
void startTrial() {
  currentPosition = 0;
  
  // NEW: Generate random target and action every time this is called
  targetOption = (int)random(NUM_OPTIONS);
  targetAction = (int)random(2);  // 0 = UP, 1 = DOWN
  
  println("NEW TRIAL: Target=" + (targetOption+1) + " Action=" + (targetAction==0?"UP":"DOWN"));
  
  countDownTimerWait = 0;
}

void goBackOneTrial() {
  // PENALTY: Go back one trial (but not below 0)
  if (currentTrial > 0) {
    currentTrial--;
  }
  
  // Start fresh trial with NEW random values
  startTrial();
  countDownTimerWait = 30; // Wait before allowing next trial
}

void completeTrial() {
  // Move to next trial
  currentTrial++;
  
  if (currentTrial < TOTAL_TRIALS) {
    // Start NEW trial with NEW random values
    startTrial();
  } else {
    // All trials complete!
    finishTime = millis();
    appState = AppState.COMPLETE;
  }
}

// ============================================================
// CLAP DETECTION
// ============================================================
void onClapDetected() {
  if (appState != AppState.TRIAL) return;
  
  // ALWAYS allow clapping
  currentPosition = (currentPosition + 1) % NUM_OPTIONS;
}

// ============================================================
// DRAW UI
// ============================================================
void drawUI() {
  // Trial counter
  fill(150);
  textSize(22);
  text("Trial " + (currentTrial + 1) + " of " + TOTAL_TRIALS, width/2, 60);
  
  if (!audioInitialized) {
    fill(0);
    textSize(24);
    text("Initializing...", width/2, height/2);
    return;
  }
  
  // Target display - SMALLER, less prominent
  fill(100);
  textSize(20);
  text("Navigate to block " + (targetOption + 1), width/2, 150);
  
  // Show required action - VERY LARGE AND CLEAR
  fill(52, 199, 89);
  textSize(72);
  String actionText = (targetAction == 0) ? "Phone Up" : "Phone Down";
  text(actionText, width/2, 250);
  
  // Instruction
  fill(100);
  textSize(24);
  text("Clap to navigate", width/2, 350);
  
  // Options grid
  int cardSize = 200;
  int spacing = 30;
  int gridWidth = (cardSize * 2) + spacing;
  int startX = (width - gridWidth) / 2;
  int startY = 450;
  
  for (int i = 0; i < NUM_OPTIONS; i++) {
    int col = i % 2;
    int row = i / 2;
    int x = startX + col * (cardSize + spacing);
    int y = startY + row * (cardSize + spacing);
    
    // Shadow
    noStroke();
    fill(0, 0, 0, 20);
    rect(x + 4, y + 4, cardSize, cardSize, 24);
    
    // GREEN BORDER if at target
    if (i == currentPosition && i == targetOption) {
      stroke(52, 199, 89, pulseAlpha + 100);
      strokeWeight(8);
      fill(52, 199, 89, 40);
      rect(x, y, cardSize, cardSize, 24);
      
      noStroke();
      fill(255);
      rect(x + 6, y + 6, cardSize - 12, cardSize - 12, 20);
    }
    else if (i == currentPosition) {
      noStroke();
      fill(0);
      rect(x, y, cardSize, cardSize, 24);
    } else if (i == targetOption) {
      noStroke();
      fill(255, 59, 48, 30);
      rect(x, y, cardSize, cardSize, 24);
    } else {
      noStroke();
      fill(255);
      rect(x, y, cardSize, cardSize, 24);
    }
    
    // Number
    if (i == currentPosition && !(i == targetOption)) {
      fill(255);
    } else {
      fill(0);
    }
    textSize(84);
    text(str(i + 1), x + cardSize/2, y + cardSize/2 + 8);
    
    // Target indicator dot
    if (i == targetOption && i != currentPosition) {
      noStroke();
      fill(255, 59, 48);
      circle(x + cardSize - 30, y + 30, 12);
    }
  }
  
  // Current position indicator
  fill(150);
  textSize(20);
  text("Current: " + (currentPosition + 1), width/2, height - 80);
}

// ============================================================
// COMPLETION - LIKE PROFESSOR'S CODE
// ============================================================
void drawCompletion() {
  // Calculate average time per trial (like professor)
  float avgTimePerTrial = (finishTime - startTime) / 1000.0 / TOTAL_TRIALS;
  
  // Title
  fill(0);
  textSize(56);
  text("Complete", width/2, 280);
  
  // Average time per trial
  fill(100);
  textSize(28);
  text("User took", width/2, 380);
  
  fill(0);
  textSize(80);
  text(nf(avgTimePerTrial, 0, 2) + "s", width/2, 490);
  
  fill(100);
  textSize(28);
  text("per trial", width/2, 560);
  
  // Total info
  fill(150);
  textSize(22);
  text("Completed " + TOTAL_TRIALS + " trials", width/2, 640);
  text("Total time: " + nf((finishTime - startTime) / 1000.0, 0, 1) + "s", width/2, 680);
}

// ============================================================
// SENSOR CALLBACKS - LIKE PROFESSOR'S SCAFFOLD
// ============================================================
void onAccelerometerEvent(float x, float y, float z) {
  if (appState != AppState.TRIAL || currentTrial >= TOTAL_TRIALS) {
    return;
  }
  
  // Like scaffold: only check when at target AND movement detected
  if (currentPosition == targetOption && abs(z - 9.8) > Z_ACCEL_THRESHOLD && countDownTimerWait < 0) {
    // Check if correct direction
    if (((z - 9.8) > Z_ACCEL_THRESHOLD && targetAction == 0) || 
        ((z - 9.8) < -Z_ACCEL_THRESHOLD && targetAction == 1)) {
      // Right target, RIGHT z direction!
      println("Right target, RIGHT z direction!");
      completeTrial();
    } else {
      // Right target, WRONG z direction!
      println("Right target, WRONG z direction!");
      goBackOneTrial();
    }
    
    countDownTimerWait = 30; // Wait before allowing next action
  }
  // Wrong position with movement - penalty
  else if (abs(z - 9.8) > Z_ACCEL_THRESHOLD && currentPosition != targetOption && countDownTimerWait < 0) {
    println("Wrong position with movement!");
    goBackOneTrial();
    countDownTimerWait = 30;
  }
}

// ============================================================
// LIFECYCLE
// ============================================================
void pause() {
  if (sensor != null) sensor.stop();
  stopAudioRecording();
}

void resume() {
  if (sensor != null) sensor.start();
  if (audioInitialized) startAudioRecording();
}

void exit() {
  stopAudioRecording();
  if (audioRecord != null) {
    audioRecord.release();
  }
  super.exit();
}
